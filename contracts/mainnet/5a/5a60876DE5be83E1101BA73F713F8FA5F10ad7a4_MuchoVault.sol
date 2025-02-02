/*                               %@@@@@@@@@@@@@@@@@(                              
                        ,@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@                        
                    /@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@.                   
                 &@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@(                
              ,@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@              
            *@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@            
           @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@          
         &@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@*        
        @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@&       
       @@@@@@@@@@@@@   #@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@   &@@@@@@@@@@@      
      &@@@@@@@@@@@    @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@.   @@@@@@@@@@,     
      @@@@@@@@@@&   .@@@@@@@@@@@@@@@@@&@@@@@@@@@&&@@@@@@@@@@@#   /@@@@@@@@@     
     &@@@@@@@@@@    @@@@@&                 %          @@@@@@@@,   #@@@@@@@@,    
     @@@@@@@@@@    @@@@@@@@%       &&        *@,       @@@@@@@@    @@@@@@@@%    
     @@@@@@@@@@    @@@@@@@@%      @@@@      /@@@.      @@@@@@@@    @@@@@@@@&    
     @@@@@@@@@@    &@@@@@@@%      @@@@      /@@@.      @@@@@@@@    @@@@@@@@/    
     .@@@@@@@@@@    @@@@@@@%      @@@@      /@@@.      @@@@@@@    &@@@@@@@@     
      @@@@@@@@@@@    @@@@&         @@        .@          @@@@.   @@@@@@@@@&     
       @@@@@@@@@@@.   @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@    @@@@@@@@@@      
        @@@@@@@@@@@@.  @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@   @@@@@@@@@@@       
         @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@        
          @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@#         
            @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@           
              @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@             
                &@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@/               
                   &@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@(                  
                       @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@#                      
                            /@@@@@@@@@@@@@@@@@@@@@@@*  */
// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "../interfaces/IMuchoVault.sol";
import "../interfaces/IMuchoHub.sol";
import "../interfaces/IMuchoBadgeManager.sol";
import "../interfaces/IPriceFeed.sol";
import "./MuchoRoles.sol";
import "../lib/UintSafe.sol";

contract MuchoVault is IMuchoVault, MuchoRoles, ReentrancyGuard{

    using SafeERC20 for IERC20;
    using SafeMath for uint256;
    using SafeMath for uint8;
    using UintSafe for uint256;

    VaultInfo[] private vaultInfo;

    /*-------------------------TYPES---------------------------------------------*/
    // Same (special fee) for MuchoBadge NFT holders:
    struct MuchoBadgeSpecialFee{  
        uint256 fee;  
        bool exists; 
    }

    /*--------------------------CONTRACTS---------------------------------------*/

    //HUB for handling investment in the different protocols:
    IMuchoHub public muchoHub = IMuchoHub(0x0000000000000000000000000000000000000000);
    function setMuchoHub(address _contract) external onlyAdmin{ 
        muchoHub = IMuchoHub(_contract);
        emit MuchoHubChanged(_contract); 
    }

    //Price feed to calculate USD values:
    IPriceFeed public priceFeed = IPriceFeed(0x0000000000000000000000000000000000000000);
    function setPriceFeed(address _contract) external onlyAdmin{ 
        priceFeed = IPriceFeed(_contract);
        emit PriceFeedChanged(_contract); 
    }

    //Badge Manager to get NFT holder attributes:
    IMuchoBadgeManager public badgeManager = IMuchoBadgeManager(0xC439d29ee3C7fa237da928AD3A3D6aEcA9aA0717);
    function setBadgeManager(address _contract) external onlyAdmin { 
        badgeManager = IMuchoBadgeManager(_contract);
        emit BadgeManagerChanged(_contract);
    }

    //Address where we send profits from fees:
    address public earningsAddress;
    function setEarningsAddress(address _addr) external onlyAdmin{ 
        earningsAddress = _addr; 
        emit EarningsAddressChanged(_addr);
    }


    /*--------------------------PARAMETERS--------------------------------------*/

    //Fee (basic points) we will charge for swapping between mucho tokens:
    uint256 public bpSwapMuchoTokensFee = 25;
    function setSwapMuchoTokensFee(uint256 _percent) external onlyTraderOrAdmin {
        require(_percent < 1000 && _percent >= 0, "not in range");
        bpSwapMuchoTokensFee = _percent;
        emit SwapMuchoTokensFeeChanged(_percent);
    }

    //Special fee with discount for swapping, for NFT holders. Each plan can have its own fee, otherwise will use the default one for no-NFT holders.
    mapping(uint256 => MuchoBadgeSpecialFee) public bpSwapMuchoTokensFeeForBadgeHolders;
    function setSwapMuchoTokensFeeForPlan(uint256 _planId, uint256 _percent) external onlyTraderOrAdmin {
        require(_percent < 1000 && _percent >= 0, "not in range");
        require(_planId > 0, "not valid plan");
        bpSwapMuchoTokensFeeForBadgeHolders[_planId] = MuchoBadgeSpecialFee({fee : _percent, exists: true});
        emit SwapMuchoTokensFeeForPlanChanged(_planId, _percent);
    }
    function removeSwapMuchoTokensFeeForPlan(uint256 _planId) external onlyTraderOrAdmin {
        require(_planId > 0, "not valid plan");
        bpSwapMuchoTokensFeeForBadgeHolders[_planId].exists = false;
        emit SwapMuchoTokensFeeForPlanRemoved(_planId);
    }

    //Maximum amount a user with NFT Plan can invest
    mapping(uint256 => mapping(uint256 => uint256)) maxDepositUserPlan;
    function setMaxDepositUserForPlan(uint256 _vaultId, uint256 _planId, uint256 _amount) external onlyTraderOrAdmin{
        maxDepositUserPlan[_vaultId][_planId] = _amount;
    }

    /*---------------------------------MODIFIERS and CHECKERS---------------------------------*/
    //Validates a vault ID
    modifier validVault(uint _id){
        require(_id < vaultInfo.length, "MuchoVaultV2.validVault: not valid vault id");
        _;
    }

    //Checks if there is a vault for the specified token
    function checkDuplicate(IERC20 _depositToken, IMuchoToken _muchoToken) internal view returns(bool) {
        for (uint256 i = 0; i < vaultInfo.length; ++i){
            if (vaultInfo[i].depositToken == _depositToken || vaultInfo[i].muchoToken == _muchoToken){
                return false;
            }        
        }
        return true;
    }

    /*----------------------------------VAULTS SETUP FUNCTIONS-----------------------------------------*/

    //Adds a vault:
    function addVault(IERC20Metadata _depositToken, IMuchoToken _muchoToken) external onlyAdmin returns(uint8){
        require(checkDuplicate(_depositToken, _muchoToken), "MuchoVaultV2.addVault: vault for that deposit or mucho token already exists");
        require(_depositToken.decimals() == _muchoToken.decimals(), "MuchoVaultV2.addVault: deposit and mucho token decimals cannot differ");

        vaultInfo.push(VaultInfo({
            depositToken: _depositToken,
            muchoToken: _muchoToken,
            totalStaked:0,
            stakedFromDeposits:0,
            lastUpdate: block.timestamp, 
            stakable: false,
            depositFee: 0,
            withdrawFee: 0,
            maxDepositUser: 10**30,
            maxCap: 0
        }));

        emit VaultAdded(_depositToken, _muchoToken);

        return uint8(vaultInfo.length.sub(1));
    }

    //Sets maximum amount to deposit:
    function setMaxCap(uint8 _vaultId, uint256 _max) external onlyTraderOrAdmin validVault(_vaultId){
        vaultInfo[_vaultId].maxCap = _max;
    }

    //Sets maximum amount to deposit for a user:
    function setMaxDepositUser(uint8 _vaultId, uint256 _max) external onlyTraderOrAdmin validVault(_vaultId){
        vaultInfo[_vaultId].maxDepositUser = _max;
    }

    //Sets a deposit fee for a vault:
    function setDepositFee(uint8 _vaultId, uint16 _fee) external onlyTraderOrAdmin validVault(_vaultId){
        require(_fee < 500, "MuchoVault: Max deposit fee exceeded");
        vaultInfo[_vaultId].depositFee = _fee;
        emit DepositFeeChanged(_vaultId, _fee);
    }

    //Sets a withdraw fee for a vault:
    function setWithdrawFee(uint8 _vaultId, uint16 _fee) external onlyTraderOrAdmin validVault(_vaultId){
        require(_fee < 100, "MuchoVault: Max withdraw fee exceeded");
        vaultInfo[_vaultId].withdrawFee = _fee;
        emit WithdrawFeeChanged(_vaultId, _fee);
    }

    //Opens or closes a vault for deposits:
    function setOpenVault(uint8 _vaultId, bool open) public onlyTraderOrAdmin validVault(_vaultId) {
        vaultInfo[_vaultId].stakable = open;
        if(open)
            emit VaultOpen(_vaultId);
        else
            emit VaultClose(_vaultId);
    }

    //Opens or closes ALL vaults for deposits:
    function setOpenAllVault(bool open) external onlyTraderOrAdmin {
        for (uint8 _vaultId = 0; _vaultId < vaultInfo.length; ++ _vaultId){
            setOpenVault(_vaultId, open);
        }
    }

    // Updates the totalStaked amount and refreshes apr (if it's time) in a vault:
    function updateVault(uint8 _vaultId) public onlyTraderOrAdmin validVault(_vaultId)  {
        _updateVault(_vaultId);
    }

    
    // Updates the totalStaked amount and refreshes apr (if it's time) in a vault:
    function _updateVault(uint8 _vaultId) internal   {
        //Update total staked
        vaultInfo[_vaultId].lastUpdate = block.timestamp;
        uint256 beforeStaked = vaultInfo[_vaultId].totalStaked;
        vaultInfo[_vaultId].totalStaked = muchoHub.getTotalStaked(address(vaultInfo[_vaultId].depositToken));

        emit VaultUpdated(_vaultId, beforeStaked, vaultInfo[_vaultId].totalStaked);
    }

    // Updates all vaults:
    function updateAllVaults() public onlyTraderOrAdmin {
        for (uint8 _vaultId = 0; _vaultId < vaultInfo.length; ++ _vaultId){
            updateVault(_vaultId);
        }
    }

    // Refresh Investment and update all vaults:
    function refreshAndUpdateAllVaults() external onlyTraderOrAdmin {
        muchoHub.refreshAllInvestments();
        updateAllVaults();
    }

    /*----------------------------Swaps between muchoTokens handling------------------------------*/

    //Gets the number of tokens user will get from a mucho swap:
    function getSwap(uint8 _sourceVaultId, uint256 _amountSourceMToken, uint8 _destVaultId) external view
                     validVault(_sourceVaultId) validVault(_destVaultId) returns(uint256) {
        //console.log("    SOL***getSwap***", _sourceVaultId, _amountSourceMToken, _destVaultId);
        require(_amountSourceMToken > 0, "MuchoVaultV2.swapMuchoToken: Insufficent amount");

        uint256 ownerAmount = getSwapFee(msg.sender).mul(_amountSourceMToken).div(10000);
        //console.log("    SOL - ownerAmount", ownerAmount);
        uint256 destOutAmount = 
                    getDestinationAmountMuchoTokenExchange(_sourceVaultId, _destVaultId, _amountSourceMToken, ownerAmount);

        return destOutAmount;
    }

    //Performs a muchoTokens swap
    function swap(uint8 _sourceVaultId, uint256 _amountSourceMToken, uint8 _destVaultId, uint256 _amountOutExpected, uint16 _maxSlippage) external
                     validVault(_sourceVaultId) validVault(_destVaultId) nonReentrant {

        require(_amountSourceMToken > 0, "MuchoVaultV2.swap: Insufficent amount");
        require(_maxSlippage < 10000, "MuchoVaultV2.swap: Maxslippage is not valid");
        IMuchoToken sMToken = vaultInfo[_sourceVaultId].muchoToken;
        IMuchoToken dMToken = vaultInfo[_destVaultId].muchoToken;
        require(sMToken.balanceOf(msg.sender) >= _amountSourceMToken, "MuchoVaultV2.swap: Not enough balance");
        require(_amountSourceMToken < sMToken.totalSupply().div(10), "MuchoVaultV2.swap: cannot swap more than 10% of total source");

        uint256 sourceOwnerAmount = getSwapFee(msg.sender).mul(_amountSourceMToken).div(10000);
        uint256 destOutAmount = 
                    getDestinationAmountMuchoTokenExchange(_sourceVaultId, _destVaultId, _amountSourceMToken, sourceOwnerAmount);

        require(destOutAmount > 0, "MuchoVaultV2.swap: user would get nothing");
        require(destOutAmount >= _amountOutExpected.mul(10000 - _maxSlippage).div(10000), "MuchoVaultV2.swap: Max slippage exceeded");
        require(destOutAmount < dMToken.totalSupply().div(10), "MuchoVaultV2.swap: cannot swap more than 10% of total destination");
        require(destOutAmount < vaultInfo[_destVaultId].stakedFromDeposits.div(3), "MuchoVaultV2.swap: cannot swap more than 33% of destination vault staked from deposits");

        //Move staked token
        {
            uint256 destIncreaseOrigToken = destOutAmount.mul(vaultInfo[_destVaultId].totalStaked).div(dMToken.totalSupply());
            vaultInfo[_destVaultId].totalStaked = vaultInfo[_destVaultId].totalStaked.add(destIncreaseOrigToken);
            vaultInfo[_destVaultId].stakedFromDeposits = vaultInfo[_destVaultId].stakedFromDeposits.add(destIncreaseOrigToken);
        }
        {
            uint256 sourceDecreaseOrigToken = _amountSourceMToken.sub(sourceOwnerAmount).mul(vaultInfo[_sourceVaultId].totalStaked);
            sourceDecreaseOrigToken = sourceDecreaseOrigToken.div(sMToken.totalSupply());
            //console.log("    SOL - sourceDecreaseOrigToken", sourceDecreaseOrigToken);
            //console.log("    SOL - vaultInfo[_sourceVaultId].totalStaked", vaultInfo[_sourceVaultId].totalStaked);
            require(sourceDecreaseOrigToken < vaultInfo[_sourceVaultId].totalStaked.div(10), "Cannot subtract more than 10% of total staked in source");
            require(sourceDecreaseOrigToken < vaultInfo[_sourceVaultId].stakedFromDeposits.div(3), "Cannot subtract more than 33% of deposit staked in source");
            vaultInfo[_sourceVaultId].totalStaked = vaultInfo[_sourceVaultId].totalStaked.sub(sourceDecreaseOrigToken);
            vaultInfo[_sourceVaultId].stakedFromDeposits = vaultInfo[_sourceVaultId].stakedFromDeposits.sub(sourceDecreaseOrigToken);
        }

        //Send fee to protocol owner
        if(sourceOwnerAmount > 0)
            sMToken.mint(earningsAddress, sourceOwnerAmount);
        
        //Send result to user
        dMToken.mint(msg.sender, destOutAmount);

        sMToken.burn(msg.sender, _amountSourceMToken);

        emit Swapped(msg.sender, _sourceVaultId, _amountSourceMToken, _destVaultId, _amountOutExpected, destOutAmount, sourceOwnerAmount);
        //console.log("    SOL - Burnt", _amountSourceMToken);
    }

    /*----------------------------CORE: User deposit and withdraw------------------------------*/
    
    //Deposits an amount in a vault
    function deposit(uint8 _vaultId, uint256 _amount) external validVault(_vaultId) nonReentrant {
        IMuchoToken mToken = vaultInfo[_vaultId].muchoToken;
        IERC20 dToken = vaultInfo[_vaultId].depositToken;


        /*console.log("    SOL - DEPOSITING");
        console.log("    SOL - Sender and balance", msg.sender, dToken.balanceOf(msg.sender));
        console.log("    SOL - amount", _amount);*/
        
        require(_amount != 0, "MuchoVaultV2.deposit: Insufficent amount");
        require(msg.sender != address(0), "MuchoVaultV2.deposit: address is not valid");
        require(_amount <= dToken.balanceOf(msg.sender), "MuchoVaultV2.deposit: balance too low" );
        require(vaultInfo[_vaultId].stakable, "MuchoVaultV2.deposit: not stakable");
        require(vaultInfo[_vaultId].maxCap == 0 || vaultInfo[_vaultId].maxCap >= _amount.add(vaultInfo[_vaultId].totalStaked), "MuchoVaultV2.deposit: depositing more than max allowed in total");
        uint256 wantedDeposit = _amount.add(investorVaultTotalStaked(_vaultId, msg.sender));
        require(wantedDeposit <= investorMaxAllowedDeposit(_vaultId, msg.sender), "MuchoVaultV2.deposit: depositing more than max allowed per user");
     
        // Gets the amount of deposit token locked in the contract
        uint256 totalStakedTokens = vaultInfo[_vaultId].totalStaked;

        // Gets the amount of muchoToken in existence
        uint256 totalShares = mToken.totalSupply();

        // Remove the deposit fee and calc amount after fee
        uint256 ownerDepositFee = _amount.mul(vaultInfo[_vaultId].depositFee).div(10000);
        uint256 amountAfterFee = _amount.sub(ownerDepositFee);

        /*console.log("    SOL - depositFee", vaultInfo[_vaultId].depositFee);
        console.log("    SOL - ownerDepositFee", ownerDepositFee);
        console.log("    SOL - amountAfterFee", amountAfterFee);*/

        // If no muchoToken exists, mint it 1:1 to the amount put in
        if (totalShares == 0 || totalStakedTokens == 0) {
            mToken.mint(msg.sender, amountAfterFee);
        } 
        // Calculate and mint the amount of muchoToken the depositToken is worth. The ratio will change overtime with APR
        else {
            uint256 what = amountAfterFee.mul(totalShares).div(totalStakedTokens);
            mToken.mint(msg.sender, what);
        }
        
        vaultInfo[_vaultId].totalStaked = vaultInfo[_vaultId].totalStaked.add(amountAfterFee);
        vaultInfo[_vaultId].stakedFromDeposits = vaultInfo[_vaultId].stakedFromDeposits.add(amountAfterFee);

        //console.log("    SOL - TOTAL STAKED AFTER DEP 0", vaultInfo[_vaultId].totalStaked);
        //console.log("    SOL - EXECUTING DEPOSIT FROM IN HUB");
        muchoHub.depositFrom(msg.sender, address(dToken), amountAfterFee, ownerDepositFee, earningsAddress);
        //console.log("    SOL - TOTAL STAKED AFTER DEP 1", vaultInfo[_vaultId].totalStaked);
        //console.log("    SOL - EXECUTING UPDATE VAULT");
        _updateVault(_vaultId);
        //console.log("    SOL - TOTAL STAKED AFTER DEP 2", vaultInfo[_vaultId].totalStaked);

        emit Deposited(msg.sender, _vaultId, _amount, vaultInfo[_vaultId].totalStaked);
    }

    //Withdraws from a vault. The user should have muschoTokens that will be burnt
    function withdraw(uint8 _vaultId, uint256 _share) external validVault(_vaultId) nonReentrant {
        //console.log("    SOL - WITHDRAW!!!");

        IMuchoToken mToken = vaultInfo[_vaultId].muchoToken;
        IERC20 dToken = vaultInfo[_vaultId].depositToken;

        require(_share != 0, "MuchoVaultV2.withdraw: Insufficient amount");
        require(msg.sender != address(0), "MuchoVaultV2.withdraw: address is not valid");
        require(_share <= mToken.balanceOf(msg.sender), "MuchoVaultV2.withdraw: balance too low");

        // Calculates the amount of depositToken the muchoToken is worth
        uint256 amountOut = _share.mul(vaultInfo[_vaultId].totalStaked).div(mToken.totalSupply());

        vaultInfo[_vaultId].totalStaked = vaultInfo[_vaultId].totalStaked.sub(amountOut);
        vaultInfo[_vaultId].stakedFromDeposits = vaultInfo[_vaultId].stakedFromDeposits.sub(amountOut);
        mToken.burn(msg.sender, _share);

        // Calculates withdraw fee:
        uint256 ownerWithdrawFee = amountOut.mul(vaultInfo[_vaultId].withdrawFee).div(10000);
        amountOut = amountOut.sub(ownerWithdrawFee);

        //console.log("    SOL - amountOut, ownerFee", amountOut, ownerWithdrawFee);

        muchoHub.withdrawFrom(msg.sender, address(dToken), amountOut, ownerWithdrawFee, earningsAddress);
        _updateVault(_vaultId);


        emit Withdrawn(msg.sender, _vaultId, amountOut, _share, vaultInfo[_vaultId].totalStaked);
    }


    /*---------------------------------INFO VIEWS---------------------------------------*/

    //Gets the deposit fee amount, adding owner's deposit fee (in this contract) + protocol's one
    function getDepositFee(uint8 _vaultId, uint256 _amount) external view returns(uint256){
        uint256 fee = _amount.mul(vaultInfo[_vaultId].depositFee).div(10000);
        return fee.add(muchoHub.getDepositFee(address(vaultInfo[_vaultId].depositToken), _amount.sub(fee)));
    }

    //Gets the withdraw fee amount, adding owner's withdraw fee (in this contract) + protocol's one
    function getWithdrawalFee(uint8 _vaultId, uint256 _amount) external view returns(uint256){
        uint256 fee = muchoHub.getWithdrawalFee(address(vaultInfo[_vaultId].depositToken), _amount);
        return fee.add(_amount.sub(fee).mul(vaultInfo[_vaultId].withdrawFee).div(10000));
    }

    //Gets the expected APR if we add an amount of token
    function getExpectedAPR(uint8 _vaultId, uint256 _additionalAmount) external view returns(uint256){
        return muchoHub.getExpectedAPR(address(vaultInfo[_vaultId].depositToken), _additionalAmount);
    }

    //Displays total amount of staked tokens in a vault:
    function vaultTotalStaked(uint8 _vaultId) validVault(_vaultId) external view returns(uint256) {
        return vaultInfo[_vaultId].totalStaked;
    }

    //Displays total amount of staked tokens from deposits (excluding profit) in a vault:
    function vaultStakedFromDeposits(uint8 _vaultId) validVault(_vaultId) external view returns(uint256) {
        return vaultInfo[_vaultId].stakedFromDeposits;
    }

    //Displays total amount a user has staked in a vault:
    function investorVaultTotalStaked(uint8 _vaultId, address _address) validVault(_vaultId) public view returns(uint256) {
        require(_address != address(0), "MuchoVaultV2.displayStakedBalance: No valid address");
        IMuchoToken mToken = vaultInfo[_vaultId].muchoToken;
        uint256 totalShares = mToken.totalSupply();
        if(totalShares == 0) return 0;
        uint256 amountOut = mToken.balanceOf(_address).mul(vaultInfo[_vaultId].totalStaked).div(totalShares);
        return amountOut;
    }

    //Maximum amount of token allowed to deposit for user:
    function investorMaxAllowedDeposit(uint8 _vaultId, address _user) validVault(_vaultId) public view returns(uint256){
        uint256 maxAllowed = vaultInfo[_vaultId].maxDepositUser;
        IMuchoBadgeManager.Plan[] memory plans = badgeManager.activePlansForUser(_user);
        for(uint i = 0; i < plans.length; i = i.add(1)){
            uint256 id = plans[i].id;
            if(maxDepositUserPlan[_vaultId][id] > maxAllowed)
                maxAllowed = maxDepositUserPlan[_vaultId][id];
        }

        return maxAllowed;
    }

    //Price Muchotoken vs "real" token:
    function muchoTokenToDepositTokenPrice(uint8 _vaultId) validVault(_vaultId) external view returns(uint256) {
        IMuchoToken mToken = vaultInfo[_vaultId].muchoToken;
        uint256 totalShares = mToken.totalSupply();
        uint256 amountOut = (vaultInfo[_vaultId].totalStaked).mul(10**18).div(totalShares);
        return amountOut;
    }

    //Total USD in a vault (18 decimals):
    function vaultTotalUSD(uint8 _vaultId) validVault(_vaultId) public view returns(uint256) {
         return getUSD(vaultInfo[_vaultId].depositToken, vaultInfo[_vaultId].totalStaked);
    }

    //Total USD an investor has in a vault:
    function investorVaultTotalUSD(uint8 _vaultId, address _user) validVault(_vaultId) public view returns(uint256) {
        require(_user != address(0), "MuchoVaultV2.totalUserVaultUSD: Invalid address");
        IMuchoToken mToken = vaultInfo[_vaultId].muchoToken;
        uint256 mTokenUser = mToken.balanceOf(_user);
        uint256 mTokenTotal = mToken.totalSupply();

        if(mTokenUser == 0 || mTokenTotal == 0)
            return 0;

        return getUSD(vaultInfo[_vaultId].depositToken, vaultInfo[_vaultId].totalStaked.mul(mTokenUser).div(mTokenTotal));
    }

    //Total USD an investor has in all vaults:
    function investorTotalUSD(address _user) public view returns(uint256){
        require(_user != address(0), "MuchoVaultV2.totalUserUSD: Invalid address");
        uint256 total = 0;
         for (uint8 i = 0; i < vaultInfo.length; ++i){
            total = total.add(investorVaultTotalUSD(i, _user));
         }

         return total;
    }

    //Protocol TVL in USD:
    function allVaultsTotalUSD() public view returns(uint256) {
         uint256 total = 0;
         for (uint8 i = 0; i < vaultInfo.length; ++i){
            total = total.add(vaultTotalUSD(i));
         }

         return total;
    }

    //Gets a vault descriptive:
    function getVaultInfo(uint8 _vaultId) external view validVault(_vaultId) returns(VaultInfo memory){
        return vaultInfo[_vaultId];
    }
    

    /*-----------------------------------SWAP MUCHOTOKENS--------------------------------------*/

    //gets usd amount with 18 decimals for a erc20 token and amount
    function getUSD(IERC20Metadata _token, uint256 _amount) internal view returns(uint256){
        uint256 tokenPrice = priceFeed.getPrice(address(_token));
        uint256 totalUSD = tokenPrice.mul(_amount).div(10**30); //as price feed uses 30 decimals
        uint256 decimals = _token.decimals();
        if(decimals > 18){
            totalUSD = totalUSD.div(10 ** (decimals - 18));
        }
        else if(decimals < 18){
            totalUSD = totalUSD.mul(10 ** (18 - decimals));
        }

        return totalUSD;
    }

    //Gets the swap fee between muchoTokens for a user, depending on the possesion of NFT
    function getSwapFee(address _user) public view returns(uint256){
        require(_user != address(0), "Not a valid user");
        uint256 swapFee = bpSwapMuchoTokensFee;
        IMuchoBadgeManager.Plan[] memory plans = badgeManager.activePlansForUser(_user);
        for(uint i = 0; i < plans.length; i = i.add(1)){
            uint256 id = plans[i].id;
            if(bpSwapMuchoTokensFeeForBadgeHolders[id].exists && bpSwapMuchoTokensFeeForBadgeHolders[id].fee < swapFee)
                swapFee = bpSwapMuchoTokensFeeForBadgeHolders[id].fee;
        }

        return swapFee;
    }


    //Returns the amount out (destination token) and to the owner (source token) for the swap
    function getDestinationAmountMuchoTokenExchange(uint8 _sourceVaultId, 
                                            uint8 _destVaultId,
                                            uint256 _amountSourceMToken,
                                            uint256 _ownerFeeAmount) 
                                                    internal view returns(uint256){
        require(_amountSourceMToken > 0, "Insufficent amount");

        uint256 sourcePrice = priceFeed.getPrice(address(vaultInfo[_sourceVaultId].depositToken)).div(10**12);
        uint256 destPrice = priceFeed.getPrice(address(vaultInfo[_destVaultId].depositToken)).div(10**12);
        uint256 decimalsDest = vaultInfo[_destVaultId].depositToken.decimals();
        uint256 decimalsSource = vaultInfo[_sourceVaultId].depositToken.decimals();

        //console.log("    SOL - prices", sourcePrice, destPrice);
        //console.log("    SOL - decimals", decimalsSource, decimalsDest);

        //Subtract owner fee
        if(_ownerFeeAmount > 0){
            _amountSourceMToken = _amountSourceMToken.sub(_ownerFeeAmount);
        }

        //console.log("    SOL - _amountSourceMToken after owner fee", _amountSourceMToken);

        uint256 amountTargetForUser = 0;
        {
            //console.log("    SOL - source totalStaked", vaultInfo[_sourceVaultId].totalStaked);
            //console.log("    SOL - source Price", sourcePrice);
            //console.log("    SOL - dest totalSupply", vaultInfo[_destVaultId].muchoToken.totalSupply());
            amountTargetForUser = _amountSourceMToken
                                        .mul(vaultInfo[_sourceVaultId].totalStaked)
                                        .mul(sourcePrice)
                                        .mul(vaultInfo[_destVaultId].muchoToken.totalSupply());
        }
        //decimals handling
        if(decimalsDest > decimalsSource){
            //console.log("    SOL - DecimalsBiggerDif|", decimalsDest - decimalsSource);
            amountTargetForUser = amountTargetForUser.mul(10**(decimalsDest - decimalsSource));
        }
        else if(decimalsDest < decimalsSource){
            //console.log("    SOL - DecimalsSmallerDif|", decimalsSource - decimalsDest);
            amountTargetForUser = amountTargetForUser.div(10**(decimalsSource - decimalsDest));
        }

        //console.log("    SOL - source totalSupply", vaultInfo[_sourceVaultId].muchoToken.totalSupply());
        //console.log("    SOL - dest totalStaked", vaultInfo[_sourceVaultId].muchoToken.totalSupply());
        amountTargetForUser = amountTargetForUser.div(vaultInfo[_sourceVaultId].muchoToken.totalSupply())
                                    .div(vaultInfo[_destVaultId].totalStaked)
                                    .div(destPrice);

        
        return amountTargetForUser;
    }
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

library UintSafe{
    uint16 constant MAX_UINT16 = 65535;
    uint32 constant MAX_UINT32 = 4294967295;

    function CastTo16(uint256 _in) public pure returns(uint16){
        if(_in > MAX_UINT16)
            return MAX_UINT16;
        
        return uint16(_in);
    }

    function CastTo32(uint256 _in) public pure returns(uint32){
        if(_in > MAX_UINT32)
            return MAX_UINT32;
        
        return uint32(_in);
    }
}

/*                               %@@@@@@@@@@@@@@@@@(                              
                        ,@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@                        
                    /@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@.                   
                 &@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@(                
              ,@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@              
            *@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@            
           @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@          
         &@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@*        
        @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@&       
       @@@@@@@@@@@@@   #@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@   &@@@@@@@@@@@      
      &@@@@@@@@@@@    @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@.   @@@@@@@@@@,     
      @@@@@@@@@@&   .@@@@@@@@@@@@@@@@@&@@@@@@@@@&&@@@@@@@@@@@#   /@@@@@@@@@     
     &@@@@@@@@@@    @@@@@&                 %          @@@@@@@@,   #@@@@@@@@,    
     @@@@@@@@@@    @@@@@@@@%       &&        *@,       @@@@@@@@    @@@@@@@@%    
     @@@@@@@@@@    @@@@@@@@%      @@@@      /@@@.      @@@@@@@@    @@@@@@@@&    
     @@@@@@@@@@    &@@@@@@@%      @@@@      /@@@.      @@@@@@@@    @@@@@@@@/    
     .@@@@@@@@@@    @@@@@@@%      @@@@      /@@@.      @@@@@@@    &@@@@@@@@     
      @@@@@@@@@@@    @@@@&         @@        .@          @@@@.   @@@@@@@@@&     
       @@@@@@@@@@@.   @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@    @@@@@@@@@@      
        @@@@@@@@@@@@.  @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@   @@@@@@@@@@@       
         @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@        
          @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@#         
            @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@           
              @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@             
                &@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@/               
                   &@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@(                  
                       @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@#                      
                            /@@@@@@@@@@@@@@@@@@@@@@@*  */
// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import "@openzeppelin/contracts/access/AccessControl.sol";

abstract contract MuchoRoles is AccessControl{
    bytes32 public constant CONTRACT_OWNER = keccak256("CONTRACT_OWNER");
    bytes32 public constant TRADER = keccak256("TRADER");

    constructor(){
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        //_setRoleAdmin(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    modifier onlyAdmin(){
        require(hasRole(DEFAULT_ADMIN_ROLE, msg.sender), "MuchoRoles: Only for admin");
        _;
    }

    modifier onlyContractOwner(){
        require(hasRole(CONTRACT_OWNER, msg.sender), "MuchoRoles: Only for contract owner");
        _;
    }

    modifier onlyContractOwnerOrAdmin(){
        require(hasRole(CONTRACT_OWNER, msg.sender) || hasRole(DEFAULT_ADMIN_ROLE, msg.sender), "MuchoRoles: Only for contract owner or admin");
        _;
    }

    modifier onlyTraderOrAdmin(){
        require(hasRole(TRADER, msg.sender) || hasRole(DEFAULT_ADMIN_ROLE, msg.sender), "MuchoRoles: Only for trader or admin");
        _;
    }

    modifier onlyOwnerTraderOrAdmin(){
        require(hasRole(TRADER, msg.sender) || hasRole(CONTRACT_OWNER, msg.sender) || hasRole(DEFAULT_ADMIN_ROLE, msg.sender), "MuchoRoles: Only for owner, trader or admin");
        _;
    }


    modifier onlyOwner(){
        require(hasRole(CONTRACT_OWNER, msg.sender), "MuchoRoles: Only for owner");
        _;
    }

}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

interface IPriceFeed{
    function getPrice(address _token) external view returns(uint256);
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

interface IMuchoBadgeManager {
    struct Plan {
        uint256 id;
        string name;
        string uri;
        uint256 subscribers;
        Price subscriptionPrice;
        Price renewalPrice;
        uint256 time;
        bool exists;
        bool enabled;
    }

    struct Price {
        address token;
        uint256 amount;
    }

    function activePlansForUser(address _user)
        external
        view
        returns (Plan[] memory);

}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import "../lib/InvestmentPartition.sol";

/*
CONTRATO MuchoHub:

HUB de conexión con las inversiones en distintos protocolos
No guarda liquidez. Potencialmente upgradeable
Guarda una una lista de contratos MuchoInvestment, cada uno de los cuales mantiene la inversión en un protocolo diferente
En caso de upgrade deberíamos crear estructura gemela en el nuevo contrato
Es el owner de los contratos MuchoInvestment, lo que le permite mover su liquidez
En caso de upgrade tendría que transferir ese ownership
Owner: contrato MuchoVault

Operaciones de inversión (owner=MuchoVault): deposit, withdraw
Operaciones de configuración (protocolOwner): añadir, modificar o desactivar contratos MuchoInvestment (protocolos)
Operaciones de trading (trader o protocolOwner): 
        moveInvestment: mover liquidez de un MuchoInvestment a otro
        setDefaultInvestment: determinar los MuchoInvestment por defecto y su porcentaje, para cada token al agregar nueva liquidez un inversor (si no se especifica, irá al 0)
        refreshAllInvestments: llamará a updateInvestment de cada MuchoInvestment (ver siguiente slide)

Operaciones de upgrade (protocolOwner): cambiar direcciones de los contratos a los que se conecta

Vistas (públicas): getApr
*/

interface IMuchoHub{
    event Deposited(address investor, address token, uint256 amount, uint256 totalStakedAfter);
    event Withdrawn(address investor, address token, uint256 amount, uint256 totalStakedAfter);
    event ProtocolAdded(address protocol);
    event ProtocolRemoved(address protocol);
    event InvestmentMoved(address token, uint256 amount, address protocolSource, address protocolDestination);
    event DefaultInvestmentChanged(address token, InvestmentPart[] partitionListAfter);
    event InvestmentRefreshed(address protocol, address token, uint256 oldAmount, uint256 newAmount);

    function depositFrom(address _investor, address _token, uint256 _amount, uint256 _amountOwnerFee, address _feeDestination) external;
    function withdrawFrom(address _investor, address _token, uint256 _amount, uint256 _amountOwnerFee, address _feeDestination) external;

    function addProtocol(address _contract) external;
    function removeProtocol(address _contract) external;

    function moveInvestment(address _token, uint256 _amount, address _protocolSource, address _protocolDestination) external;
    function setDefaultInvestment(address _token, InvestmentPart[] calldata _partitionList) external;

    function refreshInvestment(address _protocol) external;
    function refreshAllInvestments() external;

    function getDepositFee(address _token, uint256 _amount) external view returns(uint256);
    function getWithdrawalFee(address _token, uint256 _amount) external view returns(uint256);
    function getTotalNotInvested(address _token) external view returns(uint256);
    function getTotalStaked(address _token) external view returns(uint256);
    function getTotalUSD() external view returns(uint256);
    function protocols() external view returns(address[] memory);
    function getTokenDefaults(address _token) external view returns (InvestmentPart[] memory);
    function getCurrentInvestment(address _token) external view returns(InvestmentAmountPartition memory);
    function getExpectedAPR(address _token, uint256 _additionalAmount) external view returns(uint256);
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import "./IMuchoToken.sol";
import "../lib/VaultInfo.sol";

/*
CONTRATO MuchoVault:

Punto de entrada para deposit/withdraw del inversor
No guarda liquidez. Potencialmente upgradeable
Guarda una estructura por cada vault. 
En caso de upgrade deberíamos crear estructura gemela en el nuevo contrato
Es el owner de los MuchoToken, receipt tokens de cada vault, por tanto es quien puede mintearlos o quemarlos
Es el owner de MuchoController, para hacer operaciones internas
En caso de upgrade tendría que transferir estos ownerships
Owner: protocolOwner

Operaciones públicas (inversor): deposit, withdraw
Operaciones de configuración (owner o trader): añadir, abrir o cerrar vault
Operaciones de upgrade (owner): cambiar direcciones de los contratos a los que se conecta
*/

interface IMuchoVault{
    event Deposited(address user, uint8 vaultId, uint256 amount, uint256 totalStakedAfter);
    event Withdrawn(address user, uint8 vaultId, uint256 amount, uint256 mamount, uint256 totalStakedAfter);
    event Swapped(address user, uint8 sourceVaultId, uint256 amountSourceMToken, uint8 destVaultId, uint256 amountOutExpected, uint256 amountOutActual, uint256 amountMTokenOwner);
    
    event VaultAdded(IERC20Metadata depositToken, IMuchoToken muchoToken);
    event VaultOpen(uint8 vaultId);
    event VaultClose(uint8 vaultId);
    event DepositFeeChanged(uint8 vaultId, uint16 fee);
    event WithdrawFeeChanged(uint8 vaultId, uint16 fee);
    event VaultUpdated(uint8 vaultId, uint256 amountBefore, uint256 amountAfter);
    event MuchoHubChanged(address newContract);
    event PriceFeedChanged(address newContract);
    event BadgeManagerChanged(address newContract);
    event EarningsAddressChanged(address newAddr);
    event AprUpdatePeriodChanged(uint256 secs);
    event SwapMuchoTokensFeeChanged(uint256 percent);
    event SwapMuchoTokensFeeForPlanChanged(uint256 planId, uint256 percent);
    event SwapMuchoTokensFeeForPlanRemoved(uint256 planId);

    function deposit(uint8 _vaultId, uint256 _amount) external;
    function withdraw(uint8 _vaultId, uint256 _share) external;
    
    function swap(uint8 _sourceVaultId, uint256 _amountSourceMToken, uint8 _destVaultId, uint256 _amountOutExpected, uint16 _maxSlippage) external;

    function addVault(IERC20Metadata _depositToken, IMuchoToken _muchoToken) external returns(uint8);
    function setOpenVault(uint8 _vaultId, bool open) external;
    function setOpenAllVault(bool _open) external;
    function setDepositFee(uint8 _vaultId, uint16 _fee) external;
    function setWithdrawFee(uint8 _vaultId, uint16 _fee) external;

    function updateVault(uint8 _vaultId) external;
    function updateAllVaults() external;
    function refreshAndUpdateAllVaults() external;

    function setMuchoHub(address _newContract) external;
    function setPriceFeed(address _contract) external;
    function setBadgeManager(address _contract) external;
    function setEarningsAddress(address _addr) external;

    function setSwapMuchoTokensFee(uint256 _percent) external;
    function setSwapMuchoTokensFeeForPlan(uint256 _planId, uint256 _percent) external;
    function removeSwapMuchoTokensFeeForPlan(uint256 _planId) external;

    function getSwap(uint8 _sourceVaultId, uint256 _amountSourceMToken, uint8 _destVaultId) external view returns(uint256);
    function getVaultInfo(uint8 _vaultId) external view returns(VaultInfo memory);


    function getDepositFee(uint8 _vaultId, uint256 _amount) external view returns(uint256);
    function getWithdrawalFee(uint8 _vaultId, uint256 _amount) external view returns(uint256);
    function vaultTotalUSD(uint8 _vaultId) external view returns (uint256);
    function allVaultsTotalUSD() external view returns (uint256);
    function investorVaultTotalStaked(uint8 _vaultId, address _user) external view returns (uint256);
    function investorVaultTotalUSD(uint8 _vaultId, address _user) external view returns (uint256);
    function investorTotalUSD(address _user) external view returns (uint256);
    function muchoTokenToDepositTokenPrice(uint8 _vaultId) external view returns (uint256);
    function getExpectedAPR(uint8 _vaultId, uint256 _additionalAmount) external view returns(uint256);
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.9.0) (security/ReentrancyGuard.sol)

pragma solidity ^0.8.0;

/**
 * @dev Contract module that helps prevent reentrant calls to a function.
 *
 * Inheriting from `ReentrancyGuard` will make the {nonReentrant} modifier
 * available, which can be applied to functions to make sure there are no nested
 * (reentrant) calls to them.
 *
 * Note that because there is a single `nonReentrant` guard, functions marked as
 * `nonReentrant` may not call one another. This can be worked around by making
 * those functions `private`, and then adding `external` `nonReentrant` entry
 * points to them.
 *
 * TIP: If you would like to learn more about reentrancy and alternative ways
 * to protect against it, check out our blog post
 * https://blog.openzeppelin.com/reentrancy-after-istanbul/[Reentrancy After Istanbul].
 */
abstract contract ReentrancyGuard {
    // Booleans are more expensive than uint256 or any type that takes up a full
    // word because each write operation emits an extra SLOAD to first read the
    // slot's contents, replace the bits taken up by the boolean, and then write
    // back. This is the compiler's defense against contract upgrades and
    // pointer aliasing, and it cannot be disabled.

    // The values being non-zero value makes deployment a bit more expensive,
    // but in exchange the refund on every call to nonReentrant will be lower in
    // amount. Since refunds are capped to a percentage of the total
    // transaction's gas, it is best to keep them low in cases like this one, to
    // increase the likelihood of the full refund coming into effect.
    uint256 private constant _NOT_ENTERED = 1;
    uint256 private constant _ENTERED = 2;

    uint256 private _status;

    constructor() {
        _status = _NOT_ENTERED;
    }

    /**
     * @dev Prevents a contract from calling itself, directly or indirectly.
     * Calling a `nonReentrant` function from another `nonReentrant`
     * function is not supported. It is possible to prevent this from happening
     * by making the `nonReentrant` function external, and making it call a
     * `private` function that does the actual work.
     */
    modifier nonReentrant() {
        _nonReentrantBefore();
        _;
        _nonReentrantAfter();
    }

    function _nonReentrantBefore() private {
        // On the first call to nonReentrant, _status will be _NOT_ENTERED
        require(_status != _ENTERED, "ReentrancyGuard: reentrant call");

        // Any calls to nonReentrant after this point will fail
        _status = _ENTERED;
    }

    function _nonReentrantAfter() private {
        // By storing the original value once again, a refund is triggered (see
        // https://eips.ethereum.org/EIPS/eip-2200)
        _status = _NOT_ENTERED;
    }

    /**
     * @dev Returns true if the reentrancy guard is currently set to "entered", which indicates there is a
     * `nonReentrant` function in the call stack.
     */
    function _reentrancyGuardEntered() internal view returns (bool) {
        return _status == _ENTERED;
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.9.0) (utils/math/SafeMath.sol)

pragma solidity ^0.8.0;

// CAUTION
// This version of SafeMath should only be used with Solidity 0.8 or later,
// because it relies on the compiler's built in overflow checks.

/**
 * @dev Wrappers over Solidity's arithmetic operations.
 *
 * NOTE: `SafeMath` is generally not needed starting with Solidity 0.8, since the compiler
 * now has built in overflow checking.
 */
library SafeMath {
    /**
     * @dev Returns the addition of two unsigned integers, with an overflow flag.
     *
     * _Available since v3.4._
     */
    function tryAdd(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        unchecked {
            uint256 c = a + b;
            if (c < a) return (false, 0);
            return (true, c);
        }
    }

    /**
     * @dev Returns the subtraction of two unsigned integers, with an overflow flag.
     *
     * _Available since v3.4._
     */
    function trySub(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        unchecked {
            if (b > a) return (false, 0);
            return (true, a - b);
        }
    }

    /**
     * @dev Returns the multiplication of two unsigned integers, with an overflow flag.
     *
     * _Available since v3.4._
     */
    function tryMul(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        unchecked {
            // Gas optimization: this is cheaper than requiring 'a' not being zero, but the
            // benefit is lost if 'b' is also tested.
            // See: https://github.com/OpenZeppelin/openzeppelin-contracts/pull/522
            if (a == 0) return (true, 0);
            uint256 c = a * b;
            if (c / a != b) return (false, 0);
            return (true, c);
        }
    }

    /**
     * @dev Returns the division of two unsigned integers, with a division by zero flag.
     *
     * _Available since v3.4._
     */
    function tryDiv(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        unchecked {
            if (b == 0) return (false, 0);
            return (true, a / b);
        }
    }

    /**
     * @dev Returns the remainder of dividing two unsigned integers, with a division by zero flag.
     *
     * _Available since v3.4._
     */
    function tryMod(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        unchecked {
            if (b == 0) return (false, 0);
            return (true, a % b);
        }
    }

    /**
     * @dev Returns the addition of two unsigned integers, reverting on
     * overflow.
     *
     * Counterpart to Solidity's `+` operator.
     *
     * Requirements:
     *
     * - Addition cannot overflow.
     */
    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        return a + b;
    }

    /**
     * @dev Returns the subtraction of two unsigned integers, reverting on
     * overflow (when the result is negative).
     *
     * Counterpart to Solidity's `-` operator.
     *
     * Requirements:
     *
     * - Subtraction cannot overflow.
     */
    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        return a - b;
    }

    /**
     * @dev Returns the multiplication of two unsigned integers, reverting on
     * overflow.
     *
     * Counterpart to Solidity's `*` operator.
     *
     * Requirements:
     *
     * - Multiplication cannot overflow.
     */
    function mul(uint256 a, uint256 b) internal pure returns (uint256) {
        return a * b;
    }

    /**
     * @dev Returns the integer division of two unsigned integers, reverting on
     * division by zero. The result is rounded towards zero.
     *
     * Counterpart to Solidity's `/` operator.
     *
     * Requirements:
     *
     * - The divisor cannot be zero.
     */
    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        return a / b;
    }

    /**
     * @dev Returns the remainder of dividing two unsigned integers. (unsigned integer modulo),
     * reverting when dividing by zero.
     *
     * Counterpart to Solidity's `%` operator. This function uses a `revert`
     * opcode (which leaves remaining gas untouched) while Solidity uses an
     * invalid opcode to revert (consuming all remaining gas).
     *
     * Requirements:
     *
     * - The divisor cannot be zero.
     */
    function mod(uint256 a, uint256 b) internal pure returns (uint256) {
        return a % b;
    }

    /**
     * @dev Returns the subtraction of two unsigned integers, reverting with custom message on
     * overflow (when the result is negative).
     *
     * CAUTION: This function is deprecated because it requires allocating memory for the error
     * message unnecessarily. For custom revert reasons use {trySub}.
     *
     * Counterpart to Solidity's `-` operator.
     *
     * Requirements:
     *
     * - Subtraction cannot overflow.
     */
    function sub(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        unchecked {
            require(b <= a, errorMessage);
            return a - b;
        }
    }

    /**
     * @dev Returns the integer division of two unsigned integers, reverting with custom message on
     * division by zero. The result is rounded towards zero.
     *
     * Counterpart to Solidity's `/` operator. Note: this function uses a
     * `revert` opcode (which leaves remaining gas untouched) while Solidity
     * uses an invalid opcode to revert (consuming all remaining gas).
     *
     * Requirements:
     *
     * - The divisor cannot be zero.
     */
    function div(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        unchecked {
            require(b > 0, errorMessage);
            return a / b;
        }
    }

    /**
     * @dev Returns the remainder of dividing two unsigned integers. (unsigned integer modulo),
     * reverting with custom message when dividing by zero.
     *
     * CAUTION: This function is deprecated because it requires allocating memory for the error
     * message unnecessarily. For custom revert reasons use {tryMod}.
     *
     * Counterpart to Solidity's `%` operator. This function uses a `revert`
     * opcode (which leaves remaining gas untouched) while Solidity uses an
     * invalid opcode to revert (consuming all remaining gas).
     *
     * Requirements:
     *
     * - The divisor cannot be zero.
     */
    function mod(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        unchecked {
            require(b > 0, errorMessage);
            return a % b;
        }
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.9.0) (token/ERC20/utils/SafeERC20.sol)

pragma solidity ^0.8.0;

import "../IERC20.sol";
import "../extensions/IERC20Permit.sol";
import "../../../utils/Address.sol";

/**
 * @title SafeERC20
 * @dev Wrappers around ERC20 operations that throw on failure (when the token
 * contract returns false). Tokens that return no value (and instead revert or
 * throw on failure) are also supported, non-reverting calls are assumed to be
 * successful.
 * To use this library you can add a `using SafeERC20 for IERC20;` statement to your contract,
 * which allows you to call the safe operations as `token.safeTransfer(...)`, etc.
 */
library SafeERC20 {
    using Address for address;

    /**
     * @dev Transfer `value` amount of `token` from the calling contract to `to`. If `token` returns no value,
     * non-reverting calls are assumed to be successful.
     */
    function safeTransfer(IERC20 token, address to, uint256 value) internal {
        _callOptionalReturn(token, abi.encodeWithSelector(token.transfer.selector, to, value));
    }

    /**
     * @dev Transfer `value` amount of `token` from `from` to `to`, spending the approval given by `from` to the
     * calling contract. If `token` returns no value, non-reverting calls are assumed to be successful.
     */
    function safeTransferFrom(IERC20 token, address from, address to, uint256 value) internal {
        _callOptionalReturn(token, abi.encodeWithSelector(token.transferFrom.selector, from, to, value));
    }

    /**
     * @dev Deprecated. This function has issues similar to the ones found in
     * {IERC20-approve}, and its usage is discouraged.
     *
     * Whenever possible, use {safeIncreaseAllowance} and
     * {safeDecreaseAllowance} instead.
     */
    function safeApprove(IERC20 token, address spender, uint256 value) internal {
        // safeApprove should only be called when setting an initial allowance,
        // or when resetting it to zero. To increase and decrease it, use
        // 'safeIncreaseAllowance' and 'safeDecreaseAllowance'
        require(
            (value == 0) || (token.allowance(address(this), spender) == 0),
            "SafeERC20: approve from non-zero to non-zero allowance"
        );
        _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, value));
    }

    /**
     * @dev Increase the calling contract's allowance toward `spender` by `value`. If `token` returns no value,
     * non-reverting calls are assumed to be successful.
     */
    function safeIncreaseAllowance(IERC20 token, address spender, uint256 value) internal {
        uint256 oldAllowance = token.allowance(address(this), spender);
        _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, oldAllowance + value));
    }

    /**
     * @dev Decrease the calling contract's allowance toward `spender` by `value`. If `token` returns no value,
     * non-reverting calls are assumed to be successful.
     */
    function safeDecreaseAllowance(IERC20 token, address spender, uint256 value) internal {
        unchecked {
            uint256 oldAllowance = token.allowance(address(this), spender);
            require(oldAllowance >= value, "SafeERC20: decreased allowance below zero");
            _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, oldAllowance - value));
        }
    }

    /**
     * @dev Set the calling contract's allowance toward `spender` to `value`. If `token` returns no value,
     * non-reverting calls are assumed to be successful. Compatible with tokens that require the approval to be set to
     * 0 before setting it to a non-zero value.
     */
    function forceApprove(IERC20 token, address spender, uint256 value) internal {
        bytes memory approvalCall = abi.encodeWithSelector(token.approve.selector, spender, value);

        if (!_callOptionalReturnBool(token, approvalCall)) {
            _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, 0));
            _callOptionalReturn(token, approvalCall);
        }
    }

    /**
     * @dev Use a ERC-2612 signature to set the `owner` approval toward `spender` on `token`.
     * Revert on invalid signature.
     */
    function safePermit(
        IERC20Permit token,
        address owner,
        address spender,
        uint256 value,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) internal {
        uint256 nonceBefore = token.nonces(owner);
        token.permit(owner, spender, value, deadline, v, r, s);
        uint256 nonceAfter = token.nonces(owner);
        require(nonceAfter == nonceBefore + 1, "SafeERC20: permit did not succeed");
    }

    /**
     * @dev Imitates a Solidity high-level call (i.e. a regular function call to a contract), relaxing the requirement
     * on the return value: the return value is optional (but if data is returned, it must not be false).
     * @param token The token targeted by the call.
     * @param data The call data (encoded using abi.encode or one of its variants).
     */
    function _callOptionalReturn(IERC20 token, bytes memory data) private {
        // We need to perform a low level call here, to bypass Solidity's return data size checking mechanism, since
        // we're implementing it ourselves. We use {Address-functionCall} to perform this call, which verifies that
        // the target address contains contract code and also asserts for success in the low-level call.

        bytes memory returndata = address(token).functionCall(data, "SafeERC20: low-level call failed");
        require(returndata.length == 0 || abi.decode(returndata, (bool)), "SafeERC20: ERC20 operation did not succeed");
    }

    /**
     * @dev Imitates a Solidity high-level call (i.e. a regular function call to a contract), relaxing the requirement
     * on the return value: the return value is optional (but if data is returned, it must not be false).
     * @param token The token targeted by the call.
     * @param data The call data (encoded using abi.encode or one of its variants).
     *
     * This is a variant of {_callOptionalReturn} that silents catches all reverts and returns a bool instead.
     */
    function _callOptionalReturnBool(IERC20 token, bytes memory data) private returns (bool) {
        // We need to perform a low level call here, to bypass Solidity's return data size checking mechanism, since
        // we're implementing it ourselves. We cannot use {Address-functionCall} here since this should return false
        // and not revert is the subcall reverts.

        (bool success, bytes memory returndata) = address(token).call(data);
        return
            success && (returndata.length == 0 || abi.decode(returndata, (bool))) && Address.isContract(address(token));
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.9.0) (token/ERC20/ERC20.sol)

pragma solidity ^0.8.0;

import "./IERC20.sol";
import "./extensions/IERC20Metadata.sol";
import "../../utils/Context.sol";

/**
 * @dev Implementation of the {IERC20} interface.
 *
 * This implementation is agnostic to the way tokens are created. This means
 * that a supply mechanism has to be added in a derived contract using {_mint}.
 * For a generic mechanism see {ERC20PresetMinterPauser}.
 *
 * TIP: For a detailed writeup see our guide
 * https://forum.openzeppelin.com/t/how-to-implement-erc20-supply-mechanisms/226[How
 * to implement supply mechanisms].
 *
 * The default value of {decimals} is 18. To change this, you should override
 * this function so it returns a different value.
 *
 * We have followed general OpenZeppelin Contracts guidelines: functions revert
 * instead returning `false` on failure. This behavior is nonetheless
 * conventional and does not conflict with the expectations of ERC20
 * applications.
 *
 * Additionally, an {Approval} event is emitted on calls to {transferFrom}.
 * This allows applications to reconstruct the allowance for all accounts just
 * by listening to said events. Other implementations of the EIP may not emit
 * these events, as it isn't required by the specification.
 *
 * Finally, the non-standard {decreaseAllowance} and {increaseAllowance}
 * functions have been added to mitigate the well-known issues around setting
 * allowances. See {IERC20-approve}.
 */
contract ERC20 is Context, IERC20, IERC20Metadata {
    mapping(address => uint256) private _balances;

    mapping(address => mapping(address => uint256)) private _allowances;

    uint256 private _totalSupply;

    string private _name;
    string private _symbol;

    /**
     * @dev Sets the values for {name} and {symbol}.
     *
     * All two of these values are immutable: they can only be set once during
     * construction.
     */
    constructor(string memory name_, string memory symbol_) {
        _name = name_;
        _symbol = symbol_;
    }

    /**
     * @dev Returns the name of the token.
     */
    function name() public view virtual override returns (string memory) {
        return _name;
    }

    /**
     * @dev Returns the symbol of the token, usually a shorter version of the
     * name.
     */
    function symbol() public view virtual override returns (string memory) {
        return _symbol;
    }

    /**
     * @dev Returns the number of decimals used to get its user representation.
     * For example, if `decimals` equals `2`, a balance of `505` tokens should
     * be displayed to a user as `5.05` (`505 / 10 ** 2`).
     *
     * Tokens usually opt for a value of 18, imitating the relationship between
     * Ether and Wei. This is the default value returned by this function, unless
     * it's overridden.
     *
     * NOTE: This information is only used for _display_ purposes: it in
     * no way affects any of the arithmetic of the contract, including
     * {IERC20-balanceOf} and {IERC20-transfer}.
     */
    function decimals() public view virtual override returns (uint8) {
        return 18;
    }

    /**
     * @dev See {IERC20-totalSupply}.
     */
    function totalSupply() public view virtual override returns (uint256) {
        return _totalSupply;
    }

    /**
     * @dev See {IERC20-balanceOf}.
     */
    function balanceOf(address account) public view virtual override returns (uint256) {
        return _balances[account];
    }

    /**
     * @dev See {IERC20-transfer}.
     *
     * Requirements:
     *
     * - `to` cannot be the zero address.
     * - the caller must have a balance of at least `amount`.
     */
    function transfer(address to, uint256 amount) public virtual override returns (bool) {
        address owner = _msgSender();
        _transfer(owner, to, amount);
        return true;
    }

    /**
     * @dev See {IERC20-allowance}.
     */
    function allowance(address owner, address spender) public view virtual override returns (uint256) {
        return _allowances[owner][spender];
    }

    /**
     * @dev See {IERC20-approve}.
     *
     * NOTE: If `amount` is the maximum `uint256`, the allowance is not updated on
     * `transferFrom`. This is semantically equivalent to an infinite approval.
     *
     * Requirements:
     *
     * - `spender` cannot be the zero address.
     */
    function approve(address spender, uint256 amount) public virtual override returns (bool) {
        address owner = _msgSender();
        _approve(owner, spender, amount);
        return true;
    }

    /**
     * @dev See {IERC20-transferFrom}.
     *
     * Emits an {Approval} event indicating the updated allowance. This is not
     * required by the EIP. See the note at the beginning of {ERC20}.
     *
     * NOTE: Does not update the allowance if the current allowance
     * is the maximum `uint256`.
     *
     * Requirements:
     *
     * - `from` and `to` cannot be the zero address.
     * - `from` must have a balance of at least `amount`.
     * - the caller must have allowance for ``from``'s tokens of at least
     * `amount`.
     */
    function transferFrom(address from, address to, uint256 amount) public virtual override returns (bool) {
        address spender = _msgSender();
        _spendAllowance(from, spender, amount);
        _transfer(from, to, amount);
        return true;
    }

    /**
     * @dev Atomically increases the allowance granted to `spender` by the caller.
     *
     * This is an alternative to {approve} that can be used as a mitigation for
     * problems described in {IERC20-approve}.
     *
     * Emits an {Approval} event indicating the updated allowance.
     *
     * Requirements:
     *
     * - `spender` cannot be the zero address.
     */
    function increaseAllowance(address spender, uint256 addedValue) public virtual returns (bool) {
        address owner = _msgSender();
        _approve(owner, spender, allowance(owner, spender) + addedValue);
        return true;
    }

    /**
     * @dev Atomically decreases the allowance granted to `spender` by the caller.
     *
     * This is an alternative to {approve} that can be used as a mitigation for
     * problems described in {IERC20-approve}.
     *
     * Emits an {Approval} event indicating the updated allowance.
     *
     * Requirements:
     *
     * - `spender` cannot be the zero address.
     * - `spender` must have allowance for the caller of at least
     * `subtractedValue`.
     */
    function decreaseAllowance(address spender, uint256 subtractedValue) public virtual returns (bool) {
        address owner = _msgSender();
        uint256 currentAllowance = allowance(owner, spender);
        require(currentAllowance >= subtractedValue, "ERC20: decreased allowance below zero");
        unchecked {
            _approve(owner, spender, currentAllowance - subtractedValue);
        }

        return true;
    }

    /**
     * @dev Moves `amount` of tokens from `from` to `to`.
     *
     * This internal function is equivalent to {transfer}, and can be used to
     * e.g. implement automatic token fees, slashing mechanisms, etc.
     *
     * Emits a {Transfer} event.
     *
     * Requirements:
     *
     * - `from` cannot be the zero address.
     * - `to` cannot be the zero address.
     * - `from` must have a balance of at least `amount`.
     */
    function _transfer(address from, address to, uint256 amount) internal virtual {
        require(from != address(0), "ERC20: transfer from the zero address");
        require(to != address(0), "ERC20: transfer to the zero address");

        _beforeTokenTransfer(from, to, amount);

        uint256 fromBalance = _balances[from];
        require(fromBalance >= amount, "ERC20: transfer amount exceeds balance");
        unchecked {
            _balances[from] = fromBalance - amount;
            // Overflow not possible: the sum of all balances is capped by totalSupply, and the sum is preserved by
            // decrementing then incrementing.
            _balances[to] += amount;
        }

        emit Transfer(from, to, amount);

        _afterTokenTransfer(from, to, amount);
    }

    /** @dev Creates `amount` tokens and assigns them to `account`, increasing
     * the total supply.
     *
     * Emits a {Transfer} event with `from` set to the zero address.
     *
     * Requirements:
     *
     * - `account` cannot be the zero address.
     */
    function _mint(address account, uint256 amount) internal virtual {
        require(account != address(0), "ERC20: mint to the zero address");

        _beforeTokenTransfer(address(0), account, amount);

        _totalSupply += amount;
        unchecked {
            // Overflow not possible: balance + amount is at most totalSupply + amount, which is checked above.
            _balances[account] += amount;
        }
        emit Transfer(address(0), account, amount);

        _afterTokenTransfer(address(0), account, amount);
    }

    /**
     * @dev Destroys `amount` tokens from `account`, reducing the
     * total supply.
     *
     * Emits a {Transfer} event with `to` set to the zero address.
     *
     * Requirements:
     *
     * - `account` cannot be the zero address.
     * - `account` must have at least `amount` tokens.
     */
    function _burn(address account, uint256 amount) internal virtual {
        require(account != address(0), "ERC20: burn from the zero address");

        _beforeTokenTransfer(account, address(0), amount);

        uint256 accountBalance = _balances[account];
        require(accountBalance >= amount, "ERC20: burn amount exceeds balance");
        unchecked {
            _balances[account] = accountBalance - amount;
            // Overflow not possible: amount <= accountBalance <= totalSupply.
            _totalSupply -= amount;
        }

        emit Transfer(account, address(0), amount);

        _afterTokenTransfer(account, address(0), amount);
    }

    /**
     * @dev Sets `amount` as the allowance of `spender` over the `owner` s tokens.
     *
     * This internal function is equivalent to `approve`, and can be used to
     * e.g. set automatic allowances for certain subsystems, etc.
     *
     * Emits an {Approval} event.
     *
     * Requirements:
     *
     * - `owner` cannot be the zero address.
     * - `spender` cannot be the zero address.
     */
    function _approve(address owner, address spender, uint256 amount) internal virtual {
        require(owner != address(0), "ERC20: approve from the zero address");
        require(spender != address(0), "ERC20: approve to the zero address");

        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

    /**
     * @dev Updates `owner` s allowance for `spender` based on spent `amount`.
     *
     * Does not update the allowance amount in case of infinite allowance.
     * Revert if not enough allowance is available.
     *
     * Might emit an {Approval} event.
     */
    function _spendAllowance(address owner, address spender, uint256 amount) internal virtual {
        uint256 currentAllowance = allowance(owner, spender);
        if (currentAllowance != type(uint256).max) {
            require(currentAllowance >= amount, "ERC20: insufficient allowance");
            unchecked {
                _approve(owner, spender, currentAllowance - amount);
            }
        }
    }

    /**
     * @dev Hook that is called before any transfer of tokens. This includes
     * minting and burning.
     *
     * Calling conditions:
     *
     * - when `from` and `to` are both non-zero, `amount` of ``from``'s tokens
     * will be transferred to `to`.
     * - when `from` is zero, `amount` tokens will be minted for `to`.
     * - when `to` is zero, `amount` of ``from``'s tokens will be burned.
     * - `from` and `to` are never both zero.
     *
     * To learn more about hooks, head to xref:ROOT:extending-contracts.adoc#using-hooks[Using Hooks].
     */
    function _beforeTokenTransfer(address from, address to, uint256 amount) internal virtual {}

    /**
     * @dev Hook that is called after any transfer of tokens. This includes
     * minting and burning.
     *
     * Calling conditions:
     *
     * - when `from` and `to` are both non-zero, `amount` of ``from``'s tokens
     * has been transferred to `to`.
     * - when `from` is zero, `amount` tokens have been minted for `to`.
     * - when `to` is zero, `amount` of ``from``'s tokens have been burned.
     * - `from` and `to` are never both zero.
     *
     * To learn more about hooks, head to xref:ROOT:extending-contracts.adoc#using-hooks[Using Hooks].
     */
    function _afterTokenTransfer(address from, address to, uint256 amount) internal virtual {}
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import "../interfaces/IMuchoToken.sol";

struct VaultInfo {
        IERC20Metadata depositToken;    //token deposited in the vault
        IMuchoToken muchoToken; //muchoToken receipt that will be returned to the investor

        uint256 totalStaked;    //Total depositToken staked, including rewards in backing
        uint256 stakedFromDeposits; //depositToken staked from deposits, excluding rewards

        uint256 lastUpdate;         //Last time the totalStaked amount was updated

        bool stakable;          //Inverstors can deposit

        uint16 depositFee;
        uint16 withdrawFee;

        uint256 maxDepositUser; //Maximum amount a user without NFT can invest
        uint256 maxCap; //Maximum total deposit (0 = no limit)
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

interface IMuchoToken is IERC20Metadata {
    function mint(address recipient, uint256 _amount) external;
    function burn(address _from, uint256 _amount) external ;
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

struct InvestmentPart{
    address protocol;
    uint16 percentage;
}

struct InvestmentPartition{
    InvestmentPart[] parts;
    bool defined;
}



struct InvestmentAmountPart{
    address protocol;
    uint256 amount;
}

struct InvestmentAmountPartition{
    InvestmentAmountPart[] parts;
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.9.0) (access/AccessControl.sol)

pragma solidity ^0.8.0;

import "./IAccessControl.sol";
import "../utils/Context.sol";
import "../utils/Strings.sol";
import "../utils/introspection/ERC165.sol";

/**
 * @dev Contract module that allows children to implement role-based access
 * control mechanisms. This is a lightweight version that doesn't allow enumerating role
 * members except through off-chain means by accessing the contract event logs. Some
 * applications may benefit from on-chain enumerability, for those cases see
 * {AccessControlEnumerable}.
 *
 * Roles are referred to by their `bytes32` identifier. These should be exposed
 * in the external API and be unique. The best way to achieve this is by
 * using `public constant` hash digests:
 *
 * ```solidity
 * bytes32 public constant MY_ROLE = keccak256("MY_ROLE");
 * ```
 *
 * Roles can be used to represent a set of permissions. To restrict access to a
 * function call, use {hasRole}:
 *
 * ```solidity
 * function foo() public {
 *     require(hasRole(MY_ROLE, msg.sender));
 *     ...
 * }
 * ```
 *
 * Roles can be granted and revoked dynamically via the {grantRole} and
 * {revokeRole} functions. Each role has an associated admin role, and only
 * accounts that have a role's admin role can call {grantRole} and {revokeRole}.
 *
 * By default, the admin role for all roles is `DEFAULT_ADMIN_ROLE`, which means
 * that only accounts with this role will be able to grant or revoke other
 * roles. More complex role relationships can be created by using
 * {_setRoleAdmin}.
 *
 * WARNING: The `DEFAULT_ADMIN_ROLE` is also its own admin: it has permission to
 * grant and revoke this role. Extra precautions should be taken to secure
 * accounts that have been granted it. We recommend using {AccessControlDefaultAdminRules}
 * to enforce additional security measures for this role.
 */
abstract contract AccessControl is Context, IAccessControl, ERC165 {
    struct RoleData {
        mapping(address => bool) members;
        bytes32 adminRole;
    }

    mapping(bytes32 => RoleData) private _roles;

    bytes32 public constant DEFAULT_ADMIN_ROLE = 0x00;

    /**
     * @dev Modifier that checks that an account has a specific role. Reverts
     * with a standardized message including the required role.
     *
     * The format of the revert reason is given by the following regular expression:
     *
     *  /^AccessControl: account (0x[0-9a-f]{40}) is missing role (0x[0-9a-f]{64})$/
     *
     * _Available since v4.1._
     */
    modifier onlyRole(bytes32 role) {
        _checkRole(role);
        _;
    }

    /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
        return interfaceId == type(IAccessControl).interfaceId || super.supportsInterface(interfaceId);
    }

    /**
     * @dev Returns `true` if `account` has been granted `role`.
     */
    function hasRole(bytes32 role, address account) public view virtual override returns (bool) {
        return _roles[role].members[account];
    }

    /**
     * @dev Revert with a standard message if `_msgSender()` is missing `role`.
     * Overriding this function changes the behavior of the {onlyRole} modifier.
     *
     * Format of the revert message is described in {_checkRole}.
     *
     * _Available since v4.6._
     */
    function _checkRole(bytes32 role) internal view virtual {
        _checkRole(role, _msgSender());
    }

    /**
     * @dev Revert with a standard message if `account` is missing `role`.
     *
     * The format of the revert reason is given by the following regular expression:
     *
     *  /^AccessControl: account (0x[0-9a-f]{40}) is missing role (0x[0-9a-f]{64})$/
     */
    function _checkRole(bytes32 role, address account) internal view virtual {
        if (!hasRole(role, account)) {
            revert(
                string(
                    abi.encodePacked(
                        "AccessControl: account ",
                        Strings.toHexString(account),
                        " is missing role ",
                        Strings.toHexString(uint256(role), 32)
                    )
                )
            );
        }
    }

    /**
     * @dev Returns the admin role that controls `role`. See {grantRole} and
     * {revokeRole}.
     *
     * To change a role's admin, use {_setRoleAdmin}.
     */
    function getRoleAdmin(bytes32 role) public view virtual override returns (bytes32) {
        return _roles[role].adminRole;
    }

    /**
     * @dev Grants `role` to `account`.
     *
     * If `account` had not been already granted `role`, emits a {RoleGranted}
     * event.
     *
     * Requirements:
     *
     * - the caller must have ``role``'s admin role.
     *
     * May emit a {RoleGranted} event.
     */
    function grantRole(bytes32 role, address account) public virtual override onlyRole(getRoleAdmin(role)) {
        _grantRole(role, account);
    }

    /**
     * @dev Revokes `role` from `account`.
     *
     * If `account` had been granted `role`, emits a {RoleRevoked} event.
     *
     * Requirements:
     *
     * - the caller must have ``role``'s admin role.
     *
     * May emit a {RoleRevoked} event.
     */
    function revokeRole(bytes32 role, address account) public virtual override onlyRole(getRoleAdmin(role)) {
        _revokeRole(role, account);
    }

    /**
     * @dev Revokes `role` from the calling account.
     *
     * Roles are often managed via {grantRole} and {revokeRole}: this function's
     * purpose is to provide a mechanism for accounts to lose their privileges
     * if they are compromised (such as when a trusted device is misplaced).
     *
     * If the calling account had been revoked `role`, emits a {RoleRevoked}
     * event.
     *
     * Requirements:
     *
     * - the caller must be `account`.
     *
     * May emit a {RoleRevoked} event.
     */
    function renounceRole(bytes32 role, address account) public virtual override {
        require(account == _msgSender(), "AccessControl: can only renounce roles for self");

        _revokeRole(role, account);
    }

    /**
     * @dev Grants `role` to `account`.
     *
     * If `account` had not been already granted `role`, emits a {RoleGranted}
     * event. Note that unlike {grantRole}, this function doesn't perform any
     * checks on the calling account.
     *
     * May emit a {RoleGranted} event.
     *
     * [WARNING]
     * ====
     * This function should only be called from the constructor when setting
     * up the initial roles for the system.
     *
     * Using this function in any other way is effectively circumventing the admin
     * system imposed by {AccessControl}.
     * ====
     *
     * NOTE: This function is deprecated in favor of {_grantRole}.
     */
    function _setupRole(bytes32 role, address account) internal virtual {
        _grantRole(role, account);
    }

    /**
     * @dev Sets `adminRole` as ``role``'s admin role.
     *
     * Emits a {RoleAdminChanged} event.
     */
    function _setRoleAdmin(bytes32 role, bytes32 adminRole) internal virtual {
        bytes32 previousAdminRole = getRoleAdmin(role);
        _roles[role].adminRole = adminRole;
        emit RoleAdminChanged(role, previousAdminRole, adminRole);
    }

    /**
     * @dev Grants `role` to `account`.
     *
     * Internal function without access restriction.
     *
     * May emit a {RoleGranted} event.
     */
    function _grantRole(bytes32 role, address account) internal virtual {
        if (!hasRole(role, account)) {
            _roles[role].members[account] = true;
            emit RoleGranted(role, account, _msgSender());
        }
    }

    /**
     * @dev Revokes `role` from `account`.
     *
     * Internal function without access restriction.
     *
     * May emit a {RoleRevoked} event.
     */
    function _revokeRole(bytes32 role, address account) internal virtual {
        if (hasRole(role, account)) {
            _roles[role].members[account] = false;
            emit RoleRevoked(role, account, _msgSender());
        }
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.9.0) (utils/Address.sol)

pragma solidity ^0.8.1;

/**
 * @dev Collection of functions related to the address type
 */
library Address {
    /**
     * @dev Returns true if `account` is a contract.
     *
     * [IMPORTANT]
     * ====
     * It is unsafe to assume that an address for which this function returns
     * false is an externally-owned account (EOA) and not a contract.
     *
     * Among others, `isContract` will return false for the following
     * types of addresses:
     *
     *  - an externally-owned account
     *  - a contract in construction
     *  - an address where a contract will be created
     *  - an address where a contract lived, but was destroyed
     *
     * Furthermore, `isContract` will also return true if the target contract within
     * the same transaction is already scheduled for destruction by `SELFDESTRUCT`,
     * which only has an effect at the end of a transaction.
     * ====
     *
     * [IMPORTANT]
     * ====
     * You shouldn't rely on `isContract` to protect against flash loan attacks!
     *
     * Preventing calls from contracts is highly discouraged. It breaks composability, breaks support for smart wallets
     * like Gnosis Safe, and does not provide security since it can be circumvented by calling from a contract
     * constructor.
     * ====
     */
    function isContract(address account) internal view returns (bool) {
        // This method relies on extcodesize/address.code.length, which returns 0
        // for contracts in construction, since the code is only stored at the end
        // of the constructor execution.

        return account.code.length > 0;
    }

    /**
     * @dev Replacement for Solidity's `transfer`: sends `amount` wei to
     * `recipient`, forwarding all available gas and reverting on errors.
     *
     * https://eips.ethereum.org/EIPS/eip-1884[EIP1884] increases the gas cost
     * of certain opcodes, possibly making contracts go over the 2300 gas limit
     * imposed by `transfer`, making them unable to receive funds via
     * `transfer`. {sendValue} removes this limitation.
     *
     * https://consensys.net/diligence/blog/2019/09/stop-using-soliditys-transfer-now/[Learn more].
     *
     * IMPORTANT: because control is transferred to `recipient`, care must be
     * taken to not create reentrancy vulnerabilities. Consider using
     * {ReentrancyGuard} or the
     * https://solidity.readthedocs.io/en/v0.8.0/security-considerations.html#use-the-checks-effects-interactions-pattern[checks-effects-interactions pattern].
     */
    function sendValue(address payable recipient, uint256 amount) internal {
        require(address(this).balance >= amount, "Address: insufficient balance");

        (bool success, ) = recipient.call{value: amount}("");
        require(success, "Address: unable to send value, recipient may have reverted");
    }

    /**
     * @dev Performs a Solidity function call using a low level `call`. A
     * plain `call` is an unsafe replacement for a function call: use this
     * function instead.
     *
     * If `target` reverts with a revert reason, it is bubbled up by this
     * function (like regular Solidity function calls).
     *
     * Returns the raw returned data. To convert to the expected return value,
     * use https://solidity.readthedocs.io/en/latest/units-and-global-variables.html?highlight=abi.decode#abi-encoding-and-decoding-functions[`abi.decode`].
     *
     * Requirements:
     *
     * - `target` must be a contract.
     * - calling `target` with `data` must not revert.
     *
     * _Available since v3.1._
     */
    function functionCall(address target, bytes memory data) internal returns (bytes memory) {
        return functionCallWithValue(target, data, 0, "Address: low-level call failed");
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`], but with
     * `errorMessage` as a fallback revert reason when `target` reverts.
     *
     * _Available since v3.1._
     */
    function functionCall(
        address target,
        bytes memory data,
        string memory errorMessage
    ) internal returns (bytes memory) {
        return functionCallWithValue(target, data, 0, errorMessage);
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`],
     * but also transferring `value` wei to `target`.
     *
     * Requirements:
     *
     * - the calling contract must have an ETH balance of at least `value`.
     * - the called Solidity function must be `payable`.
     *
     * _Available since v3.1._
     */
    function functionCallWithValue(address target, bytes memory data, uint256 value) internal returns (bytes memory) {
        return functionCallWithValue(target, data, value, "Address: low-level call with value failed");
    }

    /**
     * @dev Same as {xref-Address-functionCallWithValue-address-bytes-uint256-}[`functionCallWithValue`], but
     * with `errorMessage` as a fallback revert reason when `target` reverts.
     *
     * _Available since v3.1._
     */
    function functionCallWithValue(
        address target,
        bytes memory data,
        uint256 value,
        string memory errorMessage
    ) internal returns (bytes memory) {
        require(address(this).balance >= value, "Address: insufficient balance for call");
        (bool success, bytes memory returndata) = target.call{value: value}(data);
        return verifyCallResultFromTarget(target, success, returndata, errorMessage);
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`],
     * but performing a static call.
     *
     * _Available since v3.3._
     */
    function functionStaticCall(address target, bytes memory data) internal view returns (bytes memory) {
        return functionStaticCall(target, data, "Address: low-level static call failed");
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-string-}[`functionCall`],
     * but performing a static call.
     *
     * _Available since v3.3._
     */
    function functionStaticCall(
        address target,
        bytes memory data,
        string memory errorMessage
    ) internal view returns (bytes memory) {
        (bool success, bytes memory returndata) = target.staticcall(data);
        return verifyCallResultFromTarget(target, success, returndata, errorMessage);
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`],
     * but performing a delegate call.
     *
     * _Available since v3.4._
     */
    function functionDelegateCall(address target, bytes memory data) internal returns (bytes memory) {
        return functionDelegateCall(target, data, "Address: low-level delegate call failed");
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-string-}[`functionCall`],
     * but performing a delegate call.
     *
     * _Available since v3.4._
     */
    function functionDelegateCall(
        address target,
        bytes memory data,
        string memory errorMessage
    ) internal returns (bytes memory) {
        (bool success, bytes memory returndata) = target.delegatecall(data);
        return verifyCallResultFromTarget(target, success, returndata, errorMessage);
    }

    /**
     * @dev Tool to verify that a low level call to smart-contract was successful, and revert (either by bubbling
     * the revert reason or using the provided one) in case of unsuccessful call or if target was not a contract.
     *
     * _Available since v4.8._
     */
    function verifyCallResultFromTarget(
        address target,
        bool success,
        bytes memory returndata,
        string memory errorMessage
    ) internal view returns (bytes memory) {
        if (success) {
            if (returndata.length == 0) {
                // only check isContract if the call was successful and the return data is empty
                // otherwise we already know that it was a contract
                require(isContract(target), "Address: call to non-contract");
            }
            return returndata;
        } else {
            _revert(returndata, errorMessage);
        }
    }

    /**
     * @dev Tool to verify that a low level call was successful, and revert if it wasn't, either by bubbling the
     * revert reason or using the provided one.
     *
     * _Available since v4.3._
     */
    function verifyCallResult(
        bool success,
        bytes memory returndata,
        string memory errorMessage
    ) internal pure returns (bytes memory) {
        if (success) {
            return returndata;
        } else {
            _revert(returndata, errorMessage);
        }
    }

    function _revert(bytes memory returndata, string memory errorMessage) private pure {
        // Look for revert reason and bubble it up if present
        if (returndata.length > 0) {
            // The easiest way to bubble the revert reason is using memory via assembly
            /// @solidity memory-safe-assembly
            assembly {
                let returndata_size := mload(returndata)
                revert(add(32, returndata), returndata_size)
            }
        } else {
            revert(errorMessage);
        }
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.9.0) (token/ERC20/extensions/IERC20Permit.sol)

pragma solidity ^0.8.0;

/**
 * @dev Interface of the ERC20 Permit extension allowing approvals to be made via signatures, as defined in
 * https://eips.ethereum.org/EIPS/eip-2612[EIP-2612].
 *
 * Adds the {permit} method, which can be used to change an account's ERC20 allowance (see {IERC20-allowance}) by
 * presenting a message signed by the account. By not relying on {IERC20-approve}, the token holder account doesn't
 * need to send a transaction, and thus is not required to hold Ether at all.
 */
interface IERC20Permit {
    /**
     * @dev Sets `value` as the allowance of `spender` over ``owner``'s tokens,
     * given ``owner``'s signed approval.
     *
     * IMPORTANT: The same issues {IERC20-approve} has related to transaction
     * ordering also apply here.
     *
     * Emits an {Approval} event.
     *
     * Requirements:
     *
     * - `spender` cannot be the zero address.
     * - `deadline` must be a timestamp in the future.
     * - `v`, `r` and `s` must be a valid `secp256k1` signature from `owner`
     * over the EIP712-formatted function arguments.
     * - the signature must use ``owner``'s current nonce (see {nonces}).
     *
     * For more information on the signature format, see the
     * https://eips.ethereum.org/EIPS/eip-2612#specification[relevant EIP
     * section].
     */
    function permit(
        address owner,
        address spender,
        uint256 value,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external;

    /**
     * @dev Returns the current nonce for `owner`. This value must be
     * included whenever a signature is generated for {permit}.
     *
     * Every successful call to {permit} increases ``owner``'s nonce by one. This
     * prevents a signature from being used multiple times.
     */
    function nonces(address owner) external view returns (uint256);

    /**
     * @dev Returns the domain separator used in the encoding of the signature for {permit}, as defined by {EIP712}.
     */
    // solhint-disable-next-line func-name-mixedcase
    function DOMAIN_SEPARATOR() external view returns (bytes32);
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.9.0) (token/ERC20/IERC20.sol)

pragma solidity ^0.8.0;

/**
 * @dev Interface of the ERC20 standard as defined in the EIP.
 */
interface IERC20 {
    /**
     * @dev Emitted when `value` tokens are moved from one account (`from`) to
     * another (`to`).
     *
     * Note that `value` may be zero.
     */
    event Transfer(address indexed from, address indexed to, uint256 value);

    /**
     * @dev Emitted when the allowance of a `spender` for an `owner` is set by
     * a call to {approve}. `value` is the new allowance.
     */
    event Approval(address indexed owner, address indexed spender, uint256 value);

    /**
     * @dev Returns the amount of tokens in existence.
     */
    function totalSupply() external view returns (uint256);

    /**
     * @dev Returns the amount of tokens owned by `account`.
     */
    function balanceOf(address account) external view returns (uint256);

    /**
     * @dev Moves `amount` tokens from the caller's account to `to`.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transfer(address to, uint256 amount) external returns (bool);

    /**
     * @dev Returns the remaining number of tokens that `spender` will be
     * allowed to spend on behalf of `owner` through {transferFrom}. This is
     * zero by default.
     *
     * This value changes when {approve} or {transferFrom} are called.
     */
    function allowance(address owner, address spender) external view returns (uint256);

    /**
     * @dev Sets `amount` as the allowance of `spender` over the caller's tokens.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * IMPORTANT: Beware that changing an allowance with this method brings the risk
     * that someone may use both the old and the new allowance by unfortunate
     * transaction ordering. One possible solution to mitigate this race
     * condition is to first reduce the spender's allowance to 0 and set the
     * desired value afterwards:
     * https://github.com/ethereum/EIPs/issues/20#issuecomment-263524729
     *
     * Emits an {Approval} event.
     */
    function approve(address spender, uint256 amount) external returns (bool);

    /**
     * @dev Moves `amount` tokens from `from` to `to` using the
     * allowance mechanism. `amount` is then deducted from the caller's
     * allowance.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (utils/Context.sol)

pragma solidity ^0.8.0;

/**
 * @dev Provides information about the current execution context, including the
 * sender of the transaction and its data. While these are generally available
 * via msg.sender and msg.data, they should not be accessed in such a direct
 * manner, since when dealing with meta-transactions the account sending and
 * paying for execution may not be the actual sender (as far as an application
 * is concerned).
 *
 * This contract is only required for intermediate, library-like contracts.
 */
abstract contract Context {
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }

    function _msgData() internal view virtual returns (bytes calldata) {
        return msg.data;
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (token/ERC20/extensions/IERC20Metadata.sol)

pragma solidity ^0.8.0;

import "../IERC20.sol";

/**
 * @dev Interface for the optional metadata functions from the ERC20 standard.
 *
 * _Available since v4.1._
 */
interface IERC20Metadata is IERC20 {
    /**
     * @dev Returns the name of the token.
     */
    function name() external view returns (string memory);

    /**
     * @dev Returns the symbol of the token.
     */
    function symbol() external view returns (string memory);

    /**
     * @dev Returns the decimals places of the token.
     */
    function decimals() external view returns (uint8);
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (utils/introspection/ERC165.sol)

pragma solidity ^0.8.0;

import "./IERC165.sol";

/**
 * @dev Implementation of the {IERC165} interface.
 *
 * Contracts that want to implement ERC165 should inherit from this contract and override {supportsInterface} to check
 * for the additional interface id that will be supported. For example:
 *
 * ```solidity
 * function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
 *     return interfaceId == type(MyInterface).interfaceId || super.supportsInterface(interfaceId);
 * }
 * ```
 *
 * Alternatively, {ERC165Storage} provides an easier to use but more expensive implementation.
 */
abstract contract ERC165 is IERC165 {
    /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
        return interfaceId == type(IERC165).interfaceId;
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.9.0) (utils/Strings.sol)

pragma solidity ^0.8.0;

import "./math/Math.sol";
import "./math/SignedMath.sol";

/**
 * @dev String operations.
 */
library Strings {
    bytes16 private constant _SYMBOLS = "0123456789abcdef";
    uint8 private constant _ADDRESS_LENGTH = 20;

    /**
     * @dev Converts a `uint256` to its ASCII `string` decimal representation.
     */
    function toString(uint256 value) internal pure returns (string memory) {
        unchecked {
            uint256 length = Math.log10(value) + 1;
            string memory buffer = new string(length);
            uint256 ptr;
            /// @solidity memory-safe-assembly
            assembly {
                ptr := add(buffer, add(32, length))
            }
            while (true) {
                ptr--;
                /// @solidity memory-safe-assembly
                assembly {
                    mstore8(ptr, byte(mod(value, 10), _SYMBOLS))
                }
                value /= 10;
                if (value == 0) break;
            }
            return buffer;
        }
    }

    /**
     * @dev Converts a `int256` to its ASCII `string` decimal representation.
     */
    function toString(int256 value) internal pure returns (string memory) {
        return string(abi.encodePacked(value < 0 ? "-" : "", toString(SignedMath.abs(value))));
    }

    /**
     * @dev Converts a `uint256` to its ASCII `string` hexadecimal representation.
     */
    function toHexString(uint256 value) internal pure returns (string memory) {
        unchecked {
            return toHexString(value, Math.log256(value) + 1);
        }
    }

    /**
     * @dev Converts a `uint256` to its ASCII `string` hexadecimal representation with fixed length.
     */
    function toHexString(uint256 value, uint256 length) internal pure returns (string memory) {
        bytes memory buffer = new bytes(2 * length + 2);
        buffer[0] = "0";
        buffer[1] = "x";
        for (uint256 i = 2 * length + 1; i > 1; --i) {
            buffer[i] = _SYMBOLS[value & 0xf];
            value >>= 4;
        }
        require(value == 0, "Strings: hex length insufficient");
        return string(buffer);
    }

    /**
     * @dev Converts an `address` with fixed length of 20 bytes to its not checksummed ASCII `string` hexadecimal representation.
     */
    function toHexString(address addr) internal pure returns (string memory) {
        return toHexString(uint256(uint160(addr)), _ADDRESS_LENGTH);
    }

    /**
     * @dev Returns true if the two strings are equal.
     */
    function equal(string memory a, string memory b) internal pure returns (bool) {
        return keccak256(bytes(a)) == keccak256(bytes(b));
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (access/IAccessControl.sol)

pragma solidity ^0.8.0;

/**
 * @dev External interface of AccessControl declared to support ERC165 detection.
 */
interface IAccessControl {
    /**
     * @dev Emitted when `newAdminRole` is set as ``role``'s admin role, replacing `previousAdminRole`
     *
     * `DEFAULT_ADMIN_ROLE` is the starting admin for all roles, despite
     * {RoleAdminChanged} not being emitted signaling this.
     *
     * _Available since v3.1._
     */
    event RoleAdminChanged(bytes32 indexed role, bytes32 indexed previousAdminRole, bytes32 indexed newAdminRole);

    /**
     * @dev Emitted when `account` is granted `role`.
     *
     * `sender` is the account that originated the contract call, an admin role
     * bearer except when using {AccessControl-_setupRole}.
     */
    event RoleGranted(bytes32 indexed role, address indexed account, address indexed sender);

    /**
     * @dev Emitted when `account` is revoked `role`.
     *
     * `sender` is the account that originated the contract call:
     *   - if using `revokeRole`, it is the admin role bearer
     *   - if using `renounceRole`, it is the role bearer (i.e. `account`)
     */
    event RoleRevoked(bytes32 indexed role, address indexed account, address indexed sender);

    /**
     * @dev Returns `true` if `account` has been granted `role`.
     */
    function hasRole(bytes32 role, address account) external view returns (bool);

    /**
     * @dev Returns the admin role that controls `role`. See {grantRole} and
     * {revokeRole}.
     *
     * To change a role's admin, use {AccessControl-_setRoleAdmin}.
     */
    function getRoleAdmin(bytes32 role) external view returns (bytes32);

    /**
     * @dev Grants `role` to `account`.
     *
     * If `account` had not been already granted `role`, emits a {RoleGranted}
     * event.
     *
     * Requirements:
     *
     * - the caller must have ``role``'s admin role.
     */
    function grantRole(bytes32 role, address account) external;

    /**
     * @dev Revokes `role` from `account`.
     *
     * If `account` had been granted `role`, emits a {RoleRevoked} event.
     *
     * Requirements:
     *
     * - the caller must have ``role``'s admin role.
     */
    function revokeRole(bytes32 role, address account) external;

    /**
     * @dev Revokes `role` from the calling account.
     *
     * Roles are often managed via {grantRole} and {revokeRole}: this function's
     * purpose is to provide a mechanism for accounts to lose their privileges
     * if they are compromised (such as when a trusted device is misplaced).
     *
     * If the calling account had been granted `role`, emits a {RoleRevoked}
     * event.
     *
     * Requirements:
     *
     * - the caller must be `account`.
     */
    function renounceRole(bytes32 role, address account) external;
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (utils/introspection/IERC165.sol)

pragma solidity ^0.8.0;

/**
 * @dev Interface of the ERC165 standard, as defined in the
 * https://eips.ethereum.org/EIPS/eip-165[EIP].
 *
 * Implementers can declare support of contract interfaces, which can then be
 * queried by others ({ERC165Checker}).
 *
 * For an implementation, see {ERC165}.
 */
interface IERC165 {
    /**
     * @dev Returns true if this contract implements the interface defined by
     * `interfaceId`. See the corresponding
     * https://eips.ethereum.org/EIPS/eip-165#how-interfaces-are-identified[EIP section]
     * to learn more about how these ids are created.
     *
     * This function call must use less than 30 000 gas.
     */
    function supportsInterface(bytes4 interfaceId) external view returns (bool);
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.8.0) (utils/math/SignedMath.sol)

pragma solidity ^0.8.0;

/**
 * @dev Standard signed math utilities missing in the Solidity language.
 */
library SignedMath {
    /**
     * @dev Returns the largest of two signed numbers.
     */
    function max(int256 a, int256 b) internal pure returns (int256) {
        return a > b ? a : b;
    }

    /**
     * @dev Returns the smallest of two signed numbers.
     */
    function min(int256 a, int256 b) internal pure returns (int256) {
        return a < b ? a : b;
    }

    /**
     * @dev Returns the average of two signed numbers without overflow.
     * The result is rounded towards zero.
     */
    function average(int256 a, int256 b) internal pure returns (int256) {
        // Formula from the book "Hacker's Delight"
        int256 x = (a & b) + ((a ^ b) >> 1);
        return x + (int256(uint256(x) >> 255) & (a ^ b));
    }

    /**
     * @dev Returns the absolute unsigned value of a signed value.
     */
    function abs(int256 n) internal pure returns (uint256) {
        unchecked {
            // must be unchecked in order to support `n = type(int256).min`
            return uint256(n >= 0 ? n : -n);
        }
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.9.0) (utils/math/Math.sol)

pragma solidity ^0.8.0;

/**
 * @dev Standard math utilities missing in the Solidity language.
 */
library Math {
    enum Rounding {
        Down, // Toward negative infinity
        Up, // Toward infinity
        Zero // Toward zero
    }

    /**
     * @dev Returns the largest of two numbers.
     */
    function max(uint256 a, uint256 b) internal pure returns (uint256) {
        return a > b ? a : b;
    }

    /**
     * @dev Returns the smallest of two numbers.
     */
    function min(uint256 a, uint256 b) internal pure returns (uint256) {
        return a < b ? a : b;
    }

    /**
     * @dev Returns the average of two numbers. The result is rounded towards
     * zero.
     */
    function average(uint256 a, uint256 b) internal pure returns (uint256) {
        // (a + b) / 2 can overflow.
        return (a & b) + (a ^ b) / 2;
    }

    /**
     * @dev Returns the ceiling of the division of two numbers.
     *
     * This differs from standard division with `/` in that it rounds up instead
     * of rounding down.
     */
    function ceilDiv(uint256 a, uint256 b) internal pure returns (uint256) {
        // (a + b - 1) / b can overflow on addition, so we distribute.
        return a == 0 ? 0 : (a - 1) / b + 1;
    }

    /**
     * @notice Calculates floor(x * y / denominator) with full precision. Throws if result overflows a uint256 or denominator == 0
     * @dev Original credit to Remco Bloemen under MIT license (https://xn--2-umb.com/21/muldiv)
     * with further edits by Uniswap Labs also under MIT license.
     */
    function mulDiv(uint256 x, uint256 y, uint256 denominator) internal pure returns (uint256 result) {
        unchecked {
            // 512-bit multiply [prod1 prod0] = x * y. Compute the product mod 2^256 and mod 2^256 - 1, then use
            // use the Chinese Remainder Theorem to reconstruct the 512 bit result. The result is stored in two 256
            // variables such that product = prod1 * 2^256 + prod0.
            uint256 prod0; // Least significant 256 bits of the product
            uint256 prod1; // Most significant 256 bits of the product
            assembly {
                let mm := mulmod(x, y, not(0))
                prod0 := mul(x, y)
                prod1 := sub(sub(mm, prod0), lt(mm, prod0))
            }

            // Handle non-overflow cases, 256 by 256 division.
            if (prod1 == 0) {
                // Solidity will revert if denominator == 0, unlike the div opcode on its own.
                // The surrounding unchecked block does not change this fact.
                // See https://docs.soliditylang.org/en/latest/control-structures.html#checked-or-unchecked-arithmetic.
                return prod0 / denominator;
            }

            // Make sure the result is less than 2^256. Also prevents denominator == 0.
            require(denominator > prod1, "Math: mulDiv overflow");

            ///////////////////////////////////////////////
            // 512 by 256 division.
            ///////////////////////////////////////////////

            // Make division exact by subtracting the remainder from [prod1 prod0].
            uint256 remainder;
            assembly {
                // Compute remainder using mulmod.
                remainder := mulmod(x, y, denominator)

                // Subtract 256 bit number from 512 bit number.
                prod1 := sub(prod1, gt(remainder, prod0))
                prod0 := sub(prod0, remainder)
            }

            // Factor powers of two out of denominator and compute largest power of two divisor of denominator. Always >= 1.
            // See https://cs.stackexchange.com/q/138556/92363.

            // Does not overflow because the denominator cannot be zero at this stage in the function.
            uint256 twos = denominator & (~denominator + 1);
            assembly {
                // Divide denominator by twos.
                denominator := div(denominator, twos)

                // Divide [prod1 prod0] by twos.
                prod0 := div(prod0, twos)

                // Flip twos such that it is 2^256 / twos. If twos is zero, then it becomes one.
                twos := add(div(sub(0, twos), twos), 1)
            }

            // Shift in bits from prod1 into prod0.
            prod0 |= prod1 * twos;

            // Invert denominator mod 2^256. Now that denominator is an odd number, it has an inverse modulo 2^256 such
            // that denominator * inv = 1 mod 2^256. Compute the inverse by starting with a seed that is correct for
            // four bits. That is, denominator * inv = 1 mod 2^4.
            uint256 inverse = (3 * denominator) ^ 2;

            // Use the Newton-Raphson iteration to improve the precision. Thanks to Hensel's lifting lemma, this also works
            // in modular arithmetic, doubling the correct bits in each step.
            inverse *= 2 - denominator * inverse; // inverse mod 2^8
            inverse *= 2 - denominator * inverse; // inverse mod 2^16
            inverse *= 2 - denominator * inverse; // inverse mod 2^32
            inverse *= 2 - denominator * inverse; // inverse mod 2^64
            inverse *= 2 - denominator * inverse; // inverse mod 2^128
            inverse *= 2 - denominator * inverse; // inverse mod 2^256

            // Because the division is now exact we can divide by multiplying with the modular inverse of denominator.
            // This will give us the correct result modulo 2^256. Since the preconditions guarantee that the outcome is
            // less than 2^256, this is the final result. We don't need to compute the high bits of the result and prod1
            // is no longer required.
            result = prod0 * inverse;
            return result;
        }
    }

    /**
     * @notice Calculates x * y / denominator with full precision, following the selected rounding direction.
     */
    function mulDiv(uint256 x, uint256 y, uint256 denominator, Rounding rounding) internal pure returns (uint256) {
        uint256 result = mulDiv(x, y, denominator);
        if (rounding == Rounding.Up && mulmod(x, y, denominator) > 0) {
            result += 1;
        }
        return result;
    }

    /**
     * @dev Returns the square root of a number. If the number is not a perfect square, the value is rounded down.
     *
     * Inspired by Henry S. Warren, Jr.'s "Hacker's Delight" (Chapter 11).
     */
    function sqrt(uint256 a) internal pure returns (uint256) {
        if (a == 0) {
            return 0;
        }

        // For our first guess, we get the biggest power of 2 which is smaller than the square root of the target.
        //
        // We know that the "msb" (most significant bit) of our target number `a` is a power of 2 such that we have
        // `msb(a) <= a < 2*msb(a)`. This value can be written `msb(a)=2**k` with `k=log2(a)`.
        //
        // This can be rewritten `2**log2(a) <= a < 2**(log2(a) + 1)`
        // → `sqrt(2**k) <= sqrt(a) < sqrt(2**(k+1))`
        // → `2**(k/2) <= sqrt(a) < 2**((k+1)/2) <= 2**(k/2 + 1)`
        //
        // Consequently, `2**(log2(a) / 2)` is a good first approximation of `sqrt(a)` with at least 1 correct bit.
        uint256 result = 1 << (log2(a) >> 1);

        // At this point `result` is an estimation with one bit of precision. We know the true value is a uint128,
        // since it is the square root of a uint256. Newton's method converges quadratically (precision doubles at
        // every iteration). We thus need at most 7 iteration to turn our partial result with one bit of precision
        // into the expected uint128 result.
        unchecked {
            result = (result + a / result) >> 1;
            result = (result + a / result) >> 1;
            result = (result + a / result) >> 1;
            result = (result + a / result) >> 1;
            result = (result + a / result) >> 1;
            result = (result + a / result) >> 1;
            result = (result + a / result) >> 1;
            return min(result, a / result);
        }
    }

    /**
     * @notice Calculates sqrt(a), following the selected rounding direction.
     */
    function sqrt(uint256 a, Rounding rounding) internal pure returns (uint256) {
        unchecked {
            uint256 result = sqrt(a);
            return result + (rounding == Rounding.Up && result * result < a ? 1 : 0);
        }
    }

    /**
     * @dev Return the log in base 2, rounded down, of a positive value.
     * Returns 0 if given 0.
     */
    function log2(uint256 value) internal pure returns (uint256) {
        uint256 result = 0;
        unchecked {
            if (value >> 128 > 0) {
                value >>= 128;
                result += 128;
            }
            if (value >> 64 > 0) {
                value >>= 64;
                result += 64;
            }
            if (value >> 32 > 0) {
                value >>= 32;
                result += 32;
            }
            if (value >> 16 > 0) {
                value >>= 16;
                result += 16;
            }
            if (value >> 8 > 0) {
                value >>= 8;
                result += 8;
            }
            if (value >> 4 > 0) {
                value >>= 4;
                result += 4;
            }
            if (value >> 2 > 0) {
                value >>= 2;
                result += 2;
            }
            if (value >> 1 > 0) {
                result += 1;
            }
        }
        return result;
    }

    /**
     * @dev Return the log in base 2, following the selected rounding direction, of a positive value.
     * Returns 0 if given 0.
     */
    function log2(uint256 value, Rounding rounding) internal pure returns (uint256) {
        unchecked {
            uint256 result = log2(value);
            return result + (rounding == Rounding.Up && 1 << result < value ? 1 : 0);
        }
    }

    /**
     * @dev Return the log in base 10, rounded down, of a positive value.
     * Returns 0 if given 0.
     */
    function log10(uint256 value) internal pure returns (uint256) {
        uint256 result = 0;
        unchecked {
            if (value >= 10 ** 64) {
                value /= 10 ** 64;
                result += 64;
            }
            if (value >= 10 ** 32) {
                value /= 10 ** 32;
                result += 32;
            }
            if (value >= 10 ** 16) {
                value /= 10 ** 16;
                result += 16;
            }
            if (value >= 10 ** 8) {
                value /= 10 ** 8;
                result += 8;
            }
            if (value >= 10 ** 4) {
                value /= 10 ** 4;
                result += 4;
            }
            if (value >= 10 ** 2) {
                value /= 10 ** 2;
                result += 2;
            }
            if (value >= 10 ** 1) {
                result += 1;
            }
        }
        return result;
    }

    /**
     * @dev Return the log in base 10, following the selected rounding direction, of a positive value.
     * Returns 0 if given 0.
     */
    function log10(uint256 value, Rounding rounding) internal pure returns (uint256) {
        unchecked {
            uint256 result = log10(value);
            return result + (rounding == Rounding.Up && 10 ** result < value ? 1 : 0);
        }
    }

    /**
     * @dev Return the log in base 256, rounded down, of a positive value.
     * Returns 0 if given 0.
     *
     * Adding one to the result gives the number of pairs of hex symbols needed to represent `value` as a hex string.
     */
    function log256(uint256 value) internal pure returns (uint256) {
        uint256 result = 0;
        unchecked {
            if (value >> 128 > 0) {
                value >>= 128;
                result += 16;
            }
            if (value >> 64 > 0) {
                value >>= 64;
                result += 8;
            }
            if (value >> 32 > 0) {
                value >>= 32;
                result += 4;
            }
            if (value >> 16 > 0) {
                value >>= 16;
                result += 2;
            }
            if (value >> 8 > 0) {
                result += 1;
            }
        }
        return result;
    }

    /**
     * @dev Return the log in base 256, following the selected rounding direction, of a positive value.
     * Returns 0 if given 0.
     */
    function log256(uint256 value, Rounding rounding) internal pure returns (uint256) {
        unchecked {
            uint256 result = log256(value);
            return result + (rounding == Rounding.Up && 1 << (result << 3) < value ? 1 : 0);
        }
    }
}