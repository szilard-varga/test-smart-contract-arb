// SPDX-License-Identifier: MIT

pragma solidity ^0.8.12;

import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableMap.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

import "./interfaces/IPositionKeeper.sol";
import "./interfaces/IPositionHandler.sol";
import "./interfaces/IPriceManager.sol";
import "./interfaces/ISettingsManager.sol";
import "./interfaces/IVault.sol";
import "./interfaces/IVaultUtils.sol";
import "./interfaces/ITriggerOrderManager.sol";
import "./interfaces/IRouter.sol";
import "../swap/interfaces/ISwapRouter.sol";

import {PositionConstants} from "../constants/PositionConstants.sol";
import {OrderStatus, DataType} from "../constants/Structs.sol";

contract PositionHandler is PositionConstants, IPositionHandler, Ownable, ReentrancyGuard {
    using EnumerableMap for EnumerableMap.AddressToUintMap;

    IPositionKeeper public positionKeeper;
    IPriceManager public priceManager;
    ISettingsManager public settingsManager;
    ITriggerOrderManager public triggerOrderManager;
    ISwapRouter public swapRouter;
    IVault public vault;
    IVaultUtils public vaultUtils;
    bool public isInitialized;
    address public router;
    address public executor;

    mapping(bytes32 => bool) private processing;
    EnumerableMap.AddressToUintMap private prices;
    mapping(address => uint256) private lastPricesUpdate;

    event SetSwapRouter(address swapRouter);
    event SetRouter(address router);
    event SetExecutor(address executor);
    event SetPositionKeeper(address _positionKeeper);

    modifier onlyRouter() {
        require(msg.sender == router, "Forbidden: Not router");
        _;
    }

    modifier inProcess(bytes32 key) {
        require(!processing[key], "In processing"); //Processing
        processing[key] = true;
        _;
        processing[key] = false;
    }

    //Config functions
    function setSwapRouter(address _swapRouter) external onlyOwner {
        swapRouter = ISwapRouter(_swapRouter);
        emit SetSwapRouter(_swapRouter);
    }

    function setRouter(address _router) external onlyOwner {
        router = _router;
        emit SetRouter(_router);
    }

    function setExecutor(address _executor) external onlyOwner {
        _setExecutor(_executor);
    }

    function _setExecutor(address _executor) private {
        require(!Address.isContract(_executor), "IVLE"); //Invalid executor
        executor = _executor;
        emit SetExecutor(_executor);
    }

    function setPositionKeeper(address _positionKeeper) external onlyOwner {
        require(Address.isContract(_positionKeeper), "IVLPK"); //Invalid position keeper
        positionKeeper = IPositionKeeper(_positionKeeper);
        emit SetPositionKeeper(_positionKeeper);
    }

    function initialize(
        IPriceManager _priceManager,
        ISettingsManager _settingsManager,
        ITriggerOrderManager _triggerOrderManager,
        IVault _vault,
        IVaultUtils _vaultUtils
    ) external onlyOwner {
        require(!isInitialized, "Not initialized");
        require(Address.isContract(address(_priceManager)), "PriceManager address is invalid");
        require(Address.isContract(address(_settingsManager)), "SettingsManager address is invalid");
        require(Address.isContract(address(_triggerOrderManager)), "TriggerOrderManager address is invalid");
        require(Address.isContract(address(_vault)), "Vault address is invalid");
        require(Address.isContract(address(_vaultUtils)), "VaultUtils address is invalid");
        priceManager = _priceManager;
        settingsManager = _settingsManager;
        triggerOrderManager = _triggerOrderManager;
        vault = _vault;
        vaultUtils = _vaultUtils;
        isInitialized = true;
    }
    //End config functions

    function openNewPosition(
        bytes32 _key,
        bool _isLong, 
        uint256 _posId,
        bytes memory _data,
        uint256[] memory _params,
        uint256[] memory _prices, 
        address[] memory _path,
        bool _isDirectExecuted
    ) external override onlyRouter inProcess(_key) {
        (Position memory position, OrderInfo memory order) = abi.decode(_data, ((Position), (OrderInfo)));
        vaultUtils.validatePositionData(_isLong, _path[0], _getOrderType(order.positionType), _prices[0], _params, true);
        
        if (order.positionType == POSITION_MARKET && _isDirectExecuted) {
            _increasePosition(
                _path[0],
                order.pendingCollateral * PRICE_PRECISION,
                order.pendingSize * PRICE_PRECISION,
                _posId,
                _isLong,
                order.collateralToken,
                _prices[0],
                position
            );

            order.pendingCollateral = 0;
            order.pendingSize = 0;
        }

        positionKeeper.openNewPosition(
            _key,
            _isLong,
            _posId,
            _path,
            _params, 
            abi.encode(position, order)
        );
    }

    function modifyPosition(
        bytes32 _key, 
        uint256 _txType, 
        bytes memory _data,
        address[] memory _path,
        uint256[] memory _prices
    ) external onlyRouter inProcess(_key) {
        require(_path.length == _prices.length && _path.length > 0, "Invalid array length");
        if (_txType == ADD_COLLATERAL || _txType == REMOVE_COLLATERAL) {
            (uint256 amountIn, Position memory position) = abi.decode(_data, ((uint256), (Position)));
            _addOrRemoveCollateral(
                _key, 
                _txType, 
                amountIn, 
                _path, 
                _prices, 
                position
            );
        } else if (_txType == ADD_TRAILING_STOP) {
            (uint256[] memory params, OrderInfo memory order) = abi.decode(_data, ((uint256[]), (OrderInfo)));
            _addTrailingStop(_key, params, order);
        } else if (_txType == UPDATE_TRAILING_STOP) {
            (bool isLong, OrderInfo memory order) = abi.decode(_data, ((bool), (OrderInfo)));
            _updateTrailingStop(_key, isLong, _prices[0], order);
        } else if (_txType == CANCEL_PENDING_ORDER) {
            (Position memory position, OrderInfo memory order) = abi.decode(_data, ((Position), (OrderInfo)));
            _cancelPendingOrder(_key, position, order);
        } else if (_txType == CLOSE_POSITION) {
            (uint256 sizeDelta, Position memory position, OrderInfo memory order) = abi.decode(_data, ((uint256), (Position), (OrderInfo)));
            _closePosition(
                _key,
                sizeDelta,
                _path,
                _prices,
                position,
                order
            );
        } else if (_txType == TRIGGER_POSITION) {
            (Position memory position, OrderInfo memory order) = abi.decode(_data, ((Position), (OrderInfo)));
            _triggerPosition(
                _key,
                _path,
                _prices,
                position,
                order
            );
        } else if (_txType == CONFIRM_POSITION) {
            (
                uint256 pendingCollateral, 
                uint256 pendingSize, 
                Position memory position
            ) = abi.decode(_data, ((uint256), (uint256), (Position)));
            PositionBond memory bond = _getBond(_key);
            _confirmDelayTransaction(
                bond.isLong,
                bond.posId,
                pendingCollateral,
                pendingSize,
                _path,
                _prices,
                position
            );
        } else if (_txType == LIQUIDATE_POSITION) {
            (Position memory position) = abi.decode(_data, (Position));
            PositionBond memory bond = _getBond(_key);
            _liquidatePosition(
                bond.isLong,
                bond.posId,
                _prices,
                _path,
                position
            );
        } else if (_txType == UPDATE_TRAILING_STOP) {

        }
    }

    function setPriceAndExecuteInBatch(
        bytes32[] memory _keys, 
        bool[] memory _isLiquidates, 
        address[][] memory _batchPath,
        uint256[][] memory _batchPrices
    ) external nonReentrant {
        _setPriceAndExecuteInBatch(_keys, _isLiquidates, _batchPath, _batchPrices);
    }

    //Test function
    function setPriceAndExecute(
        bytes32 _key, 
        bool _isLiquidate, 
        address[] memory _path,
        uint256[] memory _prices
    ) external {
        bytes32[] memory keys = new bytes32[](1);
        keys[0] = _key;
        bool[] memory isLiquidates = new bool[](1);
        isLiquidates[0] = _isLiquidate;
        address[][] memory _batchPath = new address[][](1);
        _batchPath[0] = _path;
        uint256[][] memory _batchPrices = new uint256[][](1);
        _batchPrices[0] = _prices;
        _setPriceAndExecuteInBatch(keys, isLiquidates, _batchPath, _batchPrices);
    }

    function _setPriceAndExecuteInBatch(
        bytes32[] memory _keys, 
        bool[] memory _isLiquidates, 
        address[][] memory _batchPath,
        uint256[][] memory _batchPrices
    ) internal {
        require(msg.sender == executor, "Forbidden");
        require(_keys.length > 0, "Empty array");
        require(_keys.length + _isLiquidates.length + _batchPath.length + _batchPrices.length == _keys.length * 4, "Invalid array length");
        uint256 startExecuteTime = block.timestamp;
        uint256 allowedDelay = settingsManager.maxPriceUpdatedDelay() / 2;

        for (uint256 i = 0; i < _keys.length; i++) {
            require(_batchPath[i].length > 0, "Empty inner array");
            require(_batchPath[i].length == _batchPath[i].length, "Invalid inner array length");
            
            for (uint256 j = 0; j < _batchPath[i].length; j++) {
                address token = _batchPath[i][j];
                uint256 price = _batchPrices[i][j];

                if (!prices.contains(token) || lastPricesUpdate[token] <= block.timestamp - allowedDelay) {
                    lastPricesUpdate[token] = block.timestamp;
                    prices.set(token, price);
                }
            }

            _setPriceAndExecute(_keys[i], _isLiquidates[i], _batchPrices[i]);
        }

        for (uint256 i = 0; i < prices.length(); i++) {
            (address token, uint256 price) = prices.at(i);

            if (lastPricesUpdate[token] > startExecuteTime) {
                try priceManager.setLatestPrice(token, price) {}
                catch {}
            }
        }
    }

    function _setPriceAndExecute(
        bytes32 _key, 
        bool _isLiquidate, 
        uint256[] memory _prices
    ) internal {
        try IRouter(router).setPriceAndExecute(_key, _isLiquidate, _prices) {}
        catch {}
    }

    function _addOrRemoveCollateral(
        bytes32 _key,
        uint256 _txType,
        uint256 _amountIn,
        address[] memory _path,
        uint256[] memory _prices,
        Position memory _position
    ) internal {
        PositionBond memory bond = _getBond(_key);

        if (_txType == ADD_COLLATERAL) {
            _position.collateral += _amountIn;
            vaultUtils.validateSizeCollateralAmount(_position.size, _position.collateral);
            _position.reserveAmount += _amountIn;
            positionKeeper.increasePoolAmount(_path[0], bond.isLong, _amountIn);
            positionKeeper.unpackAndStorage(_key, abi.encode(_position), DataType.POSITION);
        } else {
            _position.collateral -= _amountIn;
            vaultUtils.validateSizeCollateralAmount(_position.size, _position.collateral);
            vaultUtils.validateLiquidation(_position.owner, _path[0], bond.isLong, bond.posId, true, _prices[0]);
            _position.reserveAmount -= _amountIn;
            _position.lastIncreasedTime = block.timestamp;

            vault.takeAssetOut(
                _position.owner, 
                _position.refer, 
                0,
                _amountIn, 
                positionKeeper.getPositionCollateralToken(_key), 
                _prices[_prices.length - 1]
            );

            positionKeeper.decreasePoolAmount(_path[0], bond.isLong, _amountIn);
            positionKeeper.unpackAndStorage(_key, abi.encode(_position), DataType.POSITION);
        }

        positionKeeper.emitAddOrRemoveCollateralEvent(
            _key, 
            _txType == ADD_COLLATERAL, 
            _amountIn, 
            _position.reserveAmount, 
            _position.collateral, 
            _position.size
        );
    }

    function _addTrailingStop(
        bytes32 _key,
        uint256[] memory _params,
        OrderInfo memory _order
    ) internal {
        PositionBond memory bond = _getBond(_key);
        vaultUtils.validateTrailingStopInputData(bond.owner, bond.indexToken, bond.isLong, bond.posId, _params);
        _order.pendingCollateral = _params[0];
        _order.pendingSize = _params[1];
        _order.status = OrderStatus.PENDING;
        _order.positionType = POSITION_TRAILING_STOP;
        _order.stepType = _params[2];
        _order.stpPrice = _params[3];
        _order.stepAmount = _params[4];
        positionKeeper.unpackAndStorage(_key, abi.encode(_order), DataType.ORDER);
    }

    function _cancelPendingOrder(
        bytes32 _key,
        Position memory _position,
        OrderInfo memory _order
    ) internal {
        require(_order.status == OrderStatus.PENDING, "IVLDOS/P"); //Invalid _order status, must be pending
        require(_order.positionType != POSITION_MARKET, "NACMO"); //Not allowing cancel market _order
        require(_order.pendingCollateral > 0 && _order.collateralToken != address(0), "IVLDOPDC/T"); //Invalid order pending colalteral or token
        uint256 collateral = _order.pendingCollateral;
        address token = _order.collateralToken;
        _order.pendingCollateral = 0;
        _order.pendingSize = 0;
        _order.lmtPrice = 0;
        _order.stpPrice = 0;
        _order.collateralToken = address(0);

        if (_order.positionType == POSITION_TRAILING_STOP) {
            _order.status = OrderStatus.FILLED;
            _order.positionType = POSITION_MARKET;
        } else {
            _order.status = OrderStatus.CANCELED;
        }
        
        _position.totalFee = 0;
        positionKeeper.unpackAndStorage(_key, abi.encode(_position), DataType.POSITION);
        positionKeeper.unpackAndStorage(_key, abi.encode(_order), DataType.ORDER);
        positionKeeper.emitUpdateOrderEvent(_key, _order.positionType, _order.status);

        vault.takeAssetOut(
            _position.owner, 
            address(0), 
            0,
            collateral, 
            token, 
            PRICE_PRECISION
        );
    }

    function _closePosition(
        bytes32 _key,
        uint256 _sizeDelta,
        address[] memory _path, 
        uint256[] memory _prices, 
        Position memory _position, 
        OrderInfo memory _order
    ) internal {
        require(_sizeDelta > 0, "IVLPSD"); //Invalid position size delta
        uint256 positionSize = _position.size;
        require(_sizeDelta <= positionSize, "IVLPSD/EXD"); //Invalid position size delta, exceeded position size
        PositionBond memory bond = _getBond(_key);
        _decreasePosition(
            _path[0],
            _sizeDelta,
            bond.isLong,
            bond.posId,
            _prices,
            _position
        );

        if (_sizeDelta == positionSize) {
            positionKeeper.deletePosition(_key);
        } else {
            positionKeeper.unpackAndStorage(_key, abi.encode(_position), DataType.POSITION);
        }

        positionKeeper.unpackAndStorage(_key, abi.encode(_order), DataType.ORDER);
    }

    function _triggerPosition(
        bytes32 _key,
        address[] memory _path, 
        uint256[] memory _prices, 
        Position memory _position, 
        OrderInfo memory _order
    ) internal {
        PositionBond memory bond = _getBond(_key);
        settingsManager.updateCumulativeFundingRate(_path[0], bond.isLong);
        uint8 statusFlag = vaultUtils.validateTrigger(_position.owner, _path[0], bond.isLong, bond.posId, _prices[0]);
        (bool hitTrigger, uint256 triggerAmountPercent) = triggerOrderManager.executeTriggerOrders(
            _position.owner,
            _path[0],
            bond.isLong,
            bond.posId,
            _prices[0]
        );
        require(
            (statusFlag == ORDER_FILLED || hitTrigger) &&
                (_position.owner == msg.sender || settingsManager.isManager(msg.sender)),
            "TriggerNotReady"
        );

        if (hitTrigger) {
            _decreasePosition(
                _path[0],
                (_position.size * (triggerAmountPercent)) / BASIS_POINTS_DIVISOR,
                bond.isLong,
                bond.posId,
                _prices,
                _position
            );
        }

        if (statusFlag == ORDER_FILLED) {
            if (_order.positionType == POSITION_LIMIT || _order.positionType == POSITION_STOP_MARKET) {
                _increasePosition(
                    _path[0],
                    _order.pendingCollateral * PRICE_PRECISION,
                    _order.pendingSize * PRICE_PRECISION,
                    bond.posId,
                    bond.isLong,
                    _order.collateralToken,
                    _prices[0], 
                    _position
                );
                _order.pendingCollateral = 0;
                _order.pendingSize = 0;
                _order.status = OrderStatus.FILLED;
            } else if (_order.positionType == POSITION_STOP_LIMIT) {
                _order.positionType = POSITION_LIMIT;
            } else if (_order.positionType == POSITION_TRAILING_STOP) {
                _decreasePosition(_path[0], _order.pendingSize, bond.isLong, bond.posId, _prices, _position);
                _order.positionType = POSITION_MARKET;
                _order.pendingCollateral = 0;
                _order.pendingSize = 0;
                _order.status = OrderStatus.FILLED;
            }
        }

        positionKeeper.unpackAndStorage(_key, abi.encode(_position), DataType.POSITION);
        positionKeeper.unpackAndStorage(_key, abi.encode(_order), DataType.ORDER);
        positionKeeper.emitUpdateOrderEvent(_key, _order.positionType, _order.status);
    }

    function _confirmDelayTransaction(
        bool _isLong,
        uint256 _posId,
        uint256 _pendingCollateral,
        uint256 _pendingSize,
        address[] memory _path,
        uint256[] memory _prices,
        Position memory _position
    ) internal {
        bytes32 key = _getPositionKey(_position.owner, _path[0], _isLong, _posId);
        vaultUtils.validateConfirmDelay(_position.owner, _path[0], _isLong, _posId, true);

        uint256 fee = settingsManager.collectMarginFees(
            _position.owner,
            _path[0],
            _isLong,
            _pendingSize,
            _position.size,
            _position.entryFundingRate
        );

        _increasePosition(
            _path[0],
            _pendingCollateral * PRICE_PRECISION,
            _pendingSize * PRICE_PRECISION,
            _posId,
            _isLong,
            positionKeeper.getOrder(key).collateralToken,
            _prices[0],
            _position
        );
        positionKeeper.unpackAndStorage(key, abi.encode(_position), DataType.POSITION);
        positionKeeper.emitConfirmDelayTransactionEvent(
            key,
            true,
            _pendingCollateral,
            _pendingSize,
            fee
        );
    }

    function _liquidatePosition(
        bool _isLong,
        uint256 _posId,
        uint256[] memory _prices,
        address[] memory _path,
        Position memory _position
    ) internal {
        settingsManager.updateCumulativeFundingRate(_path[0], _isLong);
        bytes32 key = _getPositionKey(_position.owner, _path[0], _isLong, _posId);
        (uint256 liquidationState, uint256 marginFees) = vaultUtils.validateLiquidation(
            _position.owner,
            _path[0],
            _isLong,
            _posId,
            false,
            _prices[0]
        );
        require(liquidationState != LIQUIDATE_NONE_EXCEED, "NLS");

        if (liquidationState == LIQUIDATE_THRESHOLD_EXCEED) {
            // Max leverage exceeded but there is collateral remaining after deducting losses so decreasePosition instead
            _decreasePosition(_path[0], _position.size, _isLong, _posId, _prices, _position);
            positionKeeper.unpackAndStorage(key, abi.encode(_position), DataType.POSITION);
            return;
        }

        vault.accountDeltaAndFeeIntoTotalBalance(true, 0, marginFees, positionKeeper.getOrder(key).collateralToken);
        uint256 bounty = (marginFees * settingsManager.bountyPercent()) / BASIS_POINTS_DIVISOR;
        vault.transferBounty(_position.refer, bounty, _getLastCollateralPath(_path), _prices[_prices.length - 1]);
        settingsManager.decreaseOpenInterest(_path[0], _position.owner, _isLong, _position.size);
        positionKeeper.decreasePoolAmount(_path[0], _isLong, marginFees);
        positionKeeper.emitLiquidatePositionEvent(_position.owner, _path[0], _isLong, _posId, _prices[0]);
        positionKeeper.deletePosition(key);
        // Pay the fee receive using the pool, we assume that in general the liquidated amount should be sufficient to cover
        // the liquidation fees
    }

    function _updateTrailingStop(
        bytes32 _key,
        bool _isLong,
        uint256 _indexPrice,
        OrderInfo memory _order
    ) internal {
        _validateTrailingStopPrice(_isLong, true, _indexPrice, _order);
        
        if (_isLong) {
            _order.stpPrice = _order.stepType == 0
                ? _indexPrice - _order.stepAmount
                : (_indexPrice * (BASIS_POINTS_DIVISOR - _order.stepAmount)) / BASIS_POINTS_DIVISOR;
        } else {
            _order.stpPrice = _order.stepType == 0
                ? _indexPrice + _order.stepAmount
                : (_indexPrice * (BASIS_POINTS_DIVISOR + _order.stepAmount)) / BASIS_POINTS_DIVISOR;
        }

        positionKeeper.unpackAndStorage(_key, abi.encode(_order), DataType.ORDER);
        positionKeeper.emitUpdateTrailingStopEvent(_key, _order.stpPrice);
    }

    function getBond(bytes32 _key) external view returns (PositionBond memory) {
        return IRouter(router).getBond(_key);
    }

    function _decreasePosition(
        address _indexToken,
        uint256 _sizeDelta,
        bool _isLong,
        uint256 _posId,
        uint256[] memory _prices,
        Position memory _position
    ) internal {
        require(_position.size > 0, "ISFPS/Z"); //Insufficient position size / zero
        settingsManager.updateCumulativeFundingRate(_indexToken, _isLong);
        bytes32 key = _getPositionKey(_position.owner, _indexToken, _isLong, _posId);
        settingsManager.decreaseOpenInterest(
            _indexToken,
            _position.owner,
            _isLong,
            _sizeDelta
        );
        positionKeeper.decreaseReservedAmount(_indexToken, _isLong, _sizeDelta);
        _position.reserveAmount -= (_position.reserveAmount * _sizeDelta) / _position.size;
        uint256 usdOut;
        uint256 usdOutFee;

        {
            (usdOut, usdOutFee, _position) = _reduceCollateral(_position.owner, _indexToken, _sizeDelta, _isLong, _posId, _prices[0], _position);
        }

        if (_position.size != _sizeDelta) {
            _position.entryFundingRate = settingsManager.cumulativeFundingRates(_indexToken, _isLong);
            _position.size -= _sizeDelta;
            vaultUtils.validateSizeCollateralAmount(_position.size, _position.collateral);
            vaultUtils.validateLiquidation(_position.owner, _indexToken, _isLong, _posId, true, _prices[0]);
            positionKeeper.emitDecreasePositionEvent(_position.owner, _indexToken, _isLong, _posId, _sizeDelta, usdOutFee, _prices[0]);
        } else {
            positionKeeper.emitClosePositionEvent(_position.owner, _indexToken, _isLong, _posId, _prices[0]);
        }

        usdOutFee += _position.totalFee;
        _position.totalFee = 0;

        if (usdOutFee <= usdOut) {
            if (usdOutFee != usdOut) {
                positionKeeper.decreasePoolAmount(_indexToken, _isLong, usdOut - usdOutFee);
            }
            
            OrderInfo memory order = positionKeeper.getOrder(key);
            vault.takeAssetOut(
                _position.owner, 
                _position.refer, 
                usdOutFee, 
                usdOut, 
                order.collateralToken, 
                _prices[_prices.length - 1]
            );
        } else if (usdOutFee != 0) {
            vault.distributeFee(_position.owner, _position.refer, usdOutFee, _indexToken);
        }
    }

    function _increasePosition(
        address _indexToken,
        uint256 _amountIn,
        uint256 _sizeDelta,
        uint256 _posId,
        bool _isLong,
        address _colalteralToken,
        uint256 _indexPrice,
        Position memory _position
    ) internal {
        settingsManager.updateCumulativeFundingRate(_indexToken, _isLong);

        if (_position.size == 0) {
            _position.averagePrice = _indexPrice;
        }

        if (_position.size > 0 && _sizeDelta > 0) {
            _position.averagePrice = priceManager.getNextAveragePrice(
                _indexToken,
                _position.size,
                _position.averagePrice,
                _isLong,
                _sizeDelta,
                _indexPrice
            );
        }
        uint256 fee = settingsManager.collectMarginFees(
            _position.owner,
            _indexToken,
            _isLong,
            _sizeDelta,
            _position.size,
            _position.entryFundingRate
        );
        _position.totalFee += fee;
        _position.collateral += _amountIn;
        _position.reserveAmount += _amountIn;
        _position.entryFundingRate = settingsManager.cumulativeFundingRates(_indexToken, _isLong);
        _position.size += _sizeDelta;
        _position.lastIncreasedTime = block.timestamp;
        _position.lastPrice = _indexPrice;
        vault.accountDeltaAndFeeIntoTotalBalance(true, 0, fee, _colalteralToken);
        settingsManager.validatePosition(_position.owner, _indexToken, _isLong, _position.size, _position.collateral);
        vaultUtils.validateLiquidation(_position.owner, _indexToken, _isLong, _posId, true, _indexPrice);
        settingsManager.increaseOpenInterest(_indexToken, _position.owner, _isLong, _sizeDelta);
        positionKeeper.increaseReservedAmount(_indexToken, _isLong, _sizeDelta);
        positionKeeper.increasePoolAmount(_indexToken, _isLong, _amountIn);
        positionKeeper.emitIncreasePositionEvent(
            _position.owner, 
            _indexToken, 
            _isLong, 
            _posId, 
            _amountIn, 
            _sizeDelta, 
            fee, 
            _indexPrice
        );
    }

    function _reduceCollateral(
        address _account,
        address _indexToken,
        uint256 _sizeDelta,
        bool _isLong,
        uint256 _posId,
        uint256 _indexPrice, 
        Position memory _position
    ) internal returns (uint256, uint256, Position memory) {
        bool hasProfit;
        uint256 adjustedDelta;

        //Scope to avoid stack too deep error
        {
            (bool _hasProfit, uint256 delta) = priceManager.getDelta(
                _indexToken,
                _position.size,
                _position.averagePrice,
                _isLong,
                _indexPrice
            );
            hasProfit = _hasProfit;
            //Calculate the proportional change in PNL = leverage * delta
            adjustedDelta = (_sizeDelta / _position.size) * delta;
        }

        uint256 usdOut;

        if (adjustedDelta > 0) {
            if (hasProfit) {
                usdOut = adjustedDelta;
                _position.realisedPnl += int256(adjustedDelta);
            } else {
                require(_position.collateral >= adjustedDelta, "AdjustedDelta exceeded positionCollateral");
                _position.collateral -= adjustedDelta;
                _position.realisedPnl -= int256(adjustedDelta);
            }
        }

        // If the _position will be closed, then transfer the remaining collateral out
        if (_position.size == _sizeDelta) {
            usdOut += _position.collateral;
            _position.collateral = 0;
        } else {
            // Reduce the _position's collateral by _collateralDelta
            // transfer _collateralDelta out
            uint256 _collateralDelta = (_position.collateral * _sizeDelta) / _position.size;
            usdOut += _collateralDelta;
            _position.collateral -= _collateralDelta;
        }

        uint256 fee;

        {
            fee = _calculateMarginFee(_indexToken, _isLong, _sizeDelta, _position);
            bytes32 key = _getPositionKey(_account, _indexToken, _isLong, _posId);
            vault.accountDeltaAndFeeIntoTotalBalance(
                hasProfit, 
                adjustedDelta, 
                fee, 
                positionKeeper.getOrder(key).collateralToken
            );
        }
        
        // If the usdOut is more or equal than the fee then deduct the fee from the usdOut directly
        // else deduct the fee from the _position's collateral
        if (usdOut < fee) {
            _position.collateral -= fee;
        }

        vaultUtils.validateDecreasePosition(_account, _indexToken, _isLong, _posId, true, _indexPrice);
        return (usdOut, fee, _position);
    }

    function _calculateMarginFee(
        address _indexToken, 
        bool _isLong, 
        uint256 _sizeDelta, 
        Position memory _position
    ) internal view returns (uint256){
        return settingsManager.collectMarginFees(
            _position.owner,
            _indexToken,
            _isLong,
            _sizeDelta,
            _position.size,
            _position.entryFundingRate
        );
    }

    /*
    @dev: Set the latest prices for fastPriceFeed
    */
    function _setLatestPrices(address _indexToken, address[] memory _collateralPath, uint256[] memory _prices) internal {
        for (uint256 i = 0; i < _prices.length; i++) {
            uint256 price = _prices[i];

            if (price > 0) {
                try priceManager.setLatestPrice(i == 0 ? _indexToken : _collateralPath[i + 1], price){}
                catch {}
            }
        }
    }

    function _getFirstCollateralPath(address[] memory _path) internal pure returns (address) {
        _validateCollateralPath(_path);
        return _path[0];
    }

    function _getLastCollateralPath(address[] memory _path) internal pure returns (address) {
        _validateCollateralPath(_path);
        return _path[_path.length - 1];
    }

    function _validateCollateralPath(address[] memory _path) internal pure {
        require(_path.length > 0 && _path.length <= 2, "ICP");
    }

    function _verifyPrices(uint256[] memory _prices) internal pure {
        require(_prices.length > 0 && _prices.length <= 3, "IPL");
        require(_prices[0] > 0, "IP0");
        
        if (_prices.length > 1 && _prices[1] == 0 && _prices[2] == 0) {
            revert("IP1/2");
        }
    }

    
    function _shouldSwap(address[] memory _collateralPath) internal view returns (bool) {
        return !(
            _checkColalteralTokenIsStable(_getFirstCollateralPath(_collateralPath)) ||
            (_collateralPath.length == 1 && settingsManager.isEnableNonStableCollateral())
        );
    }

    function _checkColalteralTokenIsStable(address _collateralToken) internal view returns (bool) {
        bool isStable = settingsManager.isStable(_collateralToken);
        bool isCollateral = settingsManager.isCollateral(_collateralToken);
        require(isStable || isCollateral, "ICT");
        require(!(isStable && isCollateral), "ICon");
        return isStable;
    }

    function _fromTokenToUSD(address _token, uint256 _tokenAmount, uint256 _price) internal view returns (uint256) {
        if (_tokenAmount == 0) {
            return 0;
        }

        uint256 decimals = priceManager.tokenDecimals(_token);
        require(decimals > 0, "IVLDEC");
        return (_tokenAmount * _price) / (10 ** decimals);
    }

    function _fromUSDToToken(address _token, uint256 _usdAmount, uint256 _price) internal view returns (uint256) {
        if (_usdAmount == 0) {
            return 0;
        }
        
        uint256 decimals = priceManager.tokenDecimals(_token);
        require(decimals > 0, "IVLDEC");
        return (_usdAmount * (10 ** decimals)) / _price;
    }

    function _valdiateSwapRouter() internal view {
        require(address(swapRouter) != address(0), "ISR");
    }

    function _getBond(bytes32 _key) internal view returns (PositionBond memory) {
        require(router != address(0), "IVLR");
        return IRouter(router).getBond(_key);
    }

    function _getOrderType(uint256 _positionType) internal pure returns (OrderType) {
        if (_positionType == POSITION_MARKET) {
            return OrderType.MARKET;
        } else if (_positionType == POSITION_LIMIT) {
            return OrderType.LIMIT;
        } else if (_positionType == POSITION_STOP_MARKET) {
            return OrderType.STOP;
        } else if (_positionType == POSITION_STOP_LIMIT) {
            return OrderType.STOP_LIMIT;
        } else {
            revert("Invalid orderType");
        }
    }

    function _validateTrailingStopPrice(
        bool _isLong,
        bool _raise,
        uint256 _indexPrice,
        OrderInfo memory _order
    ) internal pure returns (bool) {
        uint256 stopPrice;

        if (_isLong) {
            if (_order.stepType == TRAILING_STOP_TYPE_AMOUNT) {
                stopPrice = _order.stpPrice + _order.stepAmount;
            } else {
                stopPrice = (_order.stpPrice * BASIS_POINTS_DIVISOR) / (BASIS_POINTS_DIVISOR - _order.stepAmount);
            }
        } else {
            if (_order.stepType == TRAILING_STOP_TYPE_AMOUNT) {
                stopPrice = _order.stpPrice - _order.stepAmount;
            } else {
                stopPrice = (_order.stpPrice * BASIS_POINTS_DIVISOR) / (BASIS_POINTS_DIVISOR + _order.stepAmount);
            }
        }

        bool flag;

        if (
            _isLong &&
            _order.status == OrderStatus.PENDING &&
            _order.positionType == POSITION_TRAILING_STOP &&
            stopPrice <= _indexPrice
        ) {
            flag = true;
        } else if (
            !_isLong &&
            _order.status == OrderStatus.PENDING &&
            _order.positionType == POSITION_TRAILING_STOP &&
            stopPrice >= _indexPrice
        ) {
            flag = true;
        }

        if (_raise) {
            require(flag, "Incorrect price");
        }

        return flag;
    }

    //These function for test, will remove after deploying on main net
    function setInitializedForDev(bool _isInitialized) external onlyOwner {
       isInitialized = _isInitialized;
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.8.0) (utils/Address.sol)

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
     * https://diligence.consensys.net/posts/2019/09/stop-using-soliditys-transfer-now/[Learn more].
     *
     * IMPORTANT: because control is transferred to `recipient`, care must be
     * taken to not create reentrancy vulnerabilities. Consider using
     * {ReentrancyGuard} or the
     * https://solidity.readthedocs.io/en/v0.5.11/security-considerations.html#use-the-checks-effects-interactions-pattern[checks-effects-interactions pattern].
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
    function functionCallWithValue(
        address target,
        bytes memory data,
        uint256 value
    ) internal returns (bytes memory) {
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
// OpenZeppelin Contracts (last updated v4.6.0) (token/ERC20/IERC20.sol)

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
    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) external returns (bool);
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.8.0) (token/ERC20/utils/SafeERC20.sol)

pragma solidity ^0.8.0;

import "../IERC20.sol";
import "../extensions/draft-IERC20Permit.sol";
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

    function safeTransfer(
        IERC20 token,
        address to,
        uint256 value
    ) internal {
        _callOptionalReturn(token, abi.encodeWithSelector(token.transfer.selector, to, value));
    }

    function safeTransferFrom(
        IERC20 token,
        address from,
        address to,
        uint256 value
    ) internal {
        _callOptionalReturn(token, abi.encodeWithSelector(token.transferFrom.selector, from, to, value));
    }

    /**
     * @dev Deprecated. This function has issues similar to the ones found in
     * {IERC20-approve}, and its usage is discouraged.
     *
     * Whenever possible, use {safeIncreaseAllowance} and
     * {safeDecreaseAllowance} instead.
     */
    function safeApprove(
        IERC20 token,
        address spender,
        uint256 value
    ) internal {
        // safeApprove should only be called when setting an initial allowance,
        // or when resetting it to zero. To increase and decrease it, use
        // 'safeIncreaseAllowance' and 'safeDecreaseAllowance'
        require(
            (value == 0) || (token.allowance(address(this), spender) == 0),
            "SafeERC20: approve from non-zero to non-zero allowance"
        );
        _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, value));
    }

    function safeIncreaseAllowance(
        IERC20 token,
        address spender,
        uint256 value
    ) internal {
        uint256 newAllowance = token.allowance(address(this), spender) + value;
        _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, newAllowance));
    }

    function safeDecreaseAllowance(
        IERC20 token,
        address spender,
        uint256 value
    ) internal {
        unchecked {
            uint256 oldAllowance = token.allowance(address(this), spender);
            require(oldAllowance >= value, "SafeERC20: decreased allowance below zero");
            uint256 newAllowance = oldAllowance - value;
            _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, newAllowance));
        }
    }

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
        if (returndata.length > 0) {
            // Return data is optional
            require(abi.decode(returndata, (bool)), "SafeERC20: ERC20 operation did not succeed");
        }
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.7.0) (access/Ownable.sol)

pragma solidity ^0.8.0;

import "../utils/Context.sol";

/**
 * @dev Contract module which provides a basic access control mechanism, where
 * there is an account (an owner) that can be granted exclusive access to
 * specific functions.
 *
 * By default, the owner account will be the one that deploys the contract. This
 * can later be changed with {transferOwnership}.
 *
 * This module is used through inheritance. It will make available the modifier
 * `onlyOwner`, which can be applied to your functions to restrict their use to
 * the owner.
 */
abstract contract Ownable is Context {
    address private _owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    /**
     * @dev Initializes the contract setting the deployer as the initial owner.
     */
    constructor() {
        _transferOwnership(_msgSender());
    }

    /**
     * @dev Throws if called by any account other than the owner.
     */
    modifier onlyOwner() {
        _checkOwner();
        _;
    }

    /**
     * @dev Returns the address of the current owner.
     */
    function owner() public view virtual returns (address) {
        return _owner;
    }

    /**
     * @dev Throws if the sender is not the owner.
     */
    function _checkOwner() internal view virtual {
        require(owner() == _msgSender(), "Ownable: caller is not the owner");
    }

    /**
     * @dev Leaves the contract without owner. It will not be possible to call
     * `onlyOwner` functions anymore. Can only be called by the current owner.
     *
     * NOTE: Renouncing ownership will leave the contract without an owner,
     * thereby removing any functionality that is only available to the owner.
     */
    function renounceOwnership() public virtual onlyOwner {
        _transferOwnership(address(0));
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Can only be called by the current owner.
     */
    function transferOwnership(address newOwner) public virtual onlyOwner {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        _transferOwnership(newOwner);
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Internal function without access restriction.
     */
    function _transferOwnership(address newOwner) internal virtual {
        address oldOwner = _owner;
        _owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.8.0) (utils/structs/EnumerableMap.sol)
// This file was procedurally generated from scripts/generate/templates/EnumerableMap.js.

pragma solidity ^0.8.0;

import "./EnumerableSet.sol";

/**
 * @dev Library for managing an enumerable variant of Solidity's
 * https://solidity.readthedocs.io/en/latest/types.html#mapping-types[`mapping`]
 * type.
 *
 * Maps have the following properties:
 *
 * - Entries are added, removed, and checked for existence in constant time
 * (O(1)).
 * - Entries are enumerated in O(n). No guarantees are made on the ordering.
 *
 * ```
 * contract Example {
 *     // Add the library methods
 *     using EnumerableMap for EnumerableMap.UintToAddressMap;
 *
 *     // Declare a set state variable
 *     EnumerableMap.UintToAddressMap private myMap;
 * }
 * ```
 *
 * The following map types are supported:
 *
 * - `uint256 -> address` (`UintToAddressMap`) since v3.0.0
 * - `address -> uint256` (`AddressToUintMap`) since v4.6.0
 * - `bytes32 -> bytes32` (`Bytes32ToBytes32Map`) since v4.6.0
 * - `uint256 -> uint256` (`UintToUintMap`) since v4.7.0
 * - `bytes32 -> uint256` (`Bytes32ToUintMap`) since v4.7.0
 *
 * [WARNING]
 * ====
 * Trying to delete such a structure from storage will likely result in data corruption, rendering the structure
 * unusable.
 * See https://github.com/ethereum/solidity/pull/11843[ethereum/solidity#11843] for more info.
 *
 * In order to clean an EnumerableMap, you can either remove all elements one by one or create a fresh instance using an
 * array of EnumerableMap.
 * ====
 */
library EnumerableMap {
    using EnumerableSet for EnumerableSet.Bytes32Set;

    // To implement this library for multiple types with as little code
    // repetition as possible, we write it in terms of a generic Map type with
    // bytes32 keys and values.
    // The Map implementation uses private functions, and user-facing
    // implementations (such as Uint256ToAddressMap) are just wrappers around
    // the underlying Map.
    // This means that we can only create new EnumerableMaps for types that fit
    // in bytes32.

    struct Bytes32ToBytes32Map {
        // Storage of keys
        EnumerableSet.Bytes32Set _keys;
        mapping(bytes32 => bytes32) _values;
    }

    /**
     * @dev Adds a key-value pair to a map, or updates the value for an existing
     * key. O(1).
     *
     * Returns true if the key was added to the map, that is if it was not
     * already present.
     */
    function set(
        Bytes32ToBytes32Map storage map,
        bytes32 key,
        bytes32 value
    ) internal returns (bool) {
        map._values[key] = value;
        return map._keys.add(key);
    }

    /**
     * @dev Removes a key-value pair from a map. O(1).
     *
     * Returns true if the key was removed from the map, that is if it was present.
     */
    function remove(Bytes32ToBytes32Map storage map, bytes32 key) internal returns (bool) {
        delete map._values[key];
        return map._keys.remove(key);
    }

    /**
     * @dev Returns true if the key is in the map. O(1).
     */
    function contains(Bytes32ToBytes32Map storage map, bytes32 key) internal view returns (bool) {
        return map._keys.contains(key);
    }

    /**
     * @dev Returns the number of key-value pairs in the map. O(1).
     */
    function length(Bytes32ToBytes32Map storage map) internal view returns (uint256) {
        return map._keys.length();
    }

    /**
     * @dev Returns the key-value pair stored at position `index` in the map. O(1).
     *
     * Note that there are no guarantees on the ordering of entries inside the
     * array, and it may change when more entries are added or removed.
     *
     * Requirements:
     *
     * - `index` must be strictly less than {length}.
     */
    function at(Bytes32ToBytes32Map storage map, uint256 index) internal view returns (bytes32, bytes32) {
        bytes32 key = map._keys.at(index);
        return (key, map._values[key]);
    }

    /**
     * @dev Tries to returns the value associated with `key`. O(1).
     * Does not revert if `key` is not in the map.
     */
    function tryGet(Bytes32ToBytes32Map storage map, bytes32 key) internal view returns (bool, bytes32) {
        bytes32 value = map._values[key];
        if (value == bytes32(0)) {
            return (contains(map, key), bytes32(0));
        } else {
            return (true, value);
        }
    }

    /**
     * @dev Returns the value associated with `key`. O(1).
     *
     * Requirements:
     *
     * - `key` must be in the map.
     */
    function get(Bytes32ToBytes32Map storage map, bytes32 key) internal view returns (bytes32) {
        bytes32 value = map._values[key];
        require(value != 0 || contains(map, key), "EnumerableMap: nonexistent key");
        return value;
    }

    /**
     * @dev Same as {get}, with a custom error message when `key` is not in the map.
     *
     * CAUTION: This function is deprecated because it requires allocating memory for the error
     * message unnecessarily. For custom revert reasons use {tryGet}.
     */
    function get(
        Bytes32ToBytes32Map storage map,
        bytes32 key,
        string memory errorMessage
    ) internal view returns (bytes32) {
        bytes32 value = map._values[key];
        require(value != 0 || contains(map, key), errorMessage);
        return value;
    }

    // UintToUintMap

    struct UintToUintMap {
        Bytes32ToBytes32Map _inner;
    }

    /**
     * @dev Adds a key-value pair to a map, or updates the value for an existing
     * key. O(1).
     *
     * Returns true if the key was added to the map, that is if it was not
     * already present.
     */
    function set(
        UintToUintMap storage map,
        uint256 key,
        uint256 value
    ) internal returns (bool) {
        return set(map._inner, bytes32(key), bytes32(value));
    }

    /**
     * @dev Removes a value from a set. O(1).
     *
     * Returns true if the key was removed from the map, that is if it was present.
     */
    function remove(UintToUintMap storage map, uint256 key) internal returns (bool) {
        return remove(map._inner, bytes32(key));
    }

    /**
     * @dev Returns true if the key is in the map. O(1).
     */
    function contains(UintToUintMap storage map, uint256 key) internal view returns (bool) {
        return contains(map._inner, bytes32(key));
    }

    /**
     * @dev Returns the number of elements in the map. O(1).
     */
    function length(UintToUintMap storage map) internal view returns (uint256) {
        return length(map._inner);
    }

    /**
     * @dev Returns the element stored at position `index` in the set. O(1).
     * Note that there are no guarantees on the ordering of values inside the
     * array, and it may change when more values are added or removed.
     *
     * Requirements:
     *
     * - `index` must be strictly less than {length}.
     */
    function at(UintToUintMap storage map, uint256 index) internal view returns (uint256, uint256) {
        (bytes32 key, bytes32 value) = at(map._inner, index);
        return (uint256(key), uint256(value));
    }

    /**
     * @dev Tries to returns the value associated with `key`. O(1).
     * Does not revert if `key` is not in the map.
     */
    function tryGet(UintToUintMap storage map, uint256 key) internal view returns (bool, uint256) {
        (bool success, bytes32 value) = tryGet(map._inner, bytes32(key));
        return (success, uint256(value));
    }

    /**
     * @dev Returns the value associated with `key`. O(1).
     *
     * Requirements:
     *
     * - `key` must be in the map.
     */
    function get(UintToUintMap storage map, uint256 key) internal view returns (uint256) {
        return uint256(get(map._inner, bytes32(key)));
    }

    /**
     * @dev Same as {get}, with a custom error message when `key` is not in the map.
     *
     * CAUTION: This function is deprecated because it requires allocating memory for the error
     * message unnecessarily. For custom revert reasons use {tryGet}.
     */
    function get(
        UintToUintMap storage map,
        uint256 key,
        string memory errorMessage
    ) internal view returns (uint256) {
        return uint256(get(map._inner, bytes32(key), errorMessage));
    }

    // UintToAddressMap

    struct UintToAddressMap {
        Bytes32ToBytes32Map _inner;
    }

    /**
     * @dev Adds a key-value pair to a map, or updates the value for an existing
     * key. O(1).
     *
     * Returns true if the key was added to the map, that is if it was not
     * already present.
     */
    function set(
        UintToAddressMap storage map,
        uint256 key,
        address value
    ) internal returns (bool) {
        return set(map._inner, bytes32(key), bytes32(uint256(uint160(value))));
    }

    /**
     * @dev Removes a value from a set. O(1).
     *
     * Returns true if the key was removed from the map, that is if it was present.
     */
    function remove(UintToAddressMap storage map, uint256 key) internal returns (bool) {
        return remove(map._inner, bytes32(key));
    }

    /**
     * @dev Returns true if the key is in the map. O(1).
     */
    function contains(UintToAddressMap storage map, uint256 key) internal view returns (bool) {
        return contains(map._inner, bytes32(key));
    }

    /**
     * @dev Returns the number of elements in the map. O(1).
     */
    function length(UintToAddressMap storage map) internal view returns (uint256) {
        return length(map._inner);
    }

    /**
     * @dev Returns the element stored at position `index` in the set. O(1).
     * Note that there are no guarantees on the ordering of values inside the
     * array, and it may change when more values are added or removed.
     *
     * Requirements:
     *
     * - `index` must be strictly less than {length}.
     */
    function at(UintToAddressMap storage map, uint256 index) internal view returns (uint256, address) {
        (bytes32 key, bytes32 value) = at(map._inner, index);
        return (uint256(key), address(uint160(uint256(value))));
    }

    /**
     * @dev Tries to returns the value associated with `key`. O(1).
     * Does not revert if `key` is not in the map.
     */
    function tryGet(UintToAddressMap storage map, uint256 key) internal view returns (bool, address) {
        (bool success, bytes32 value) = tryGet(map._inner, bytes32(key));
        return (success, address(uint160(uint256(value))));
    }

    /**
     * @dev Returns the value associated with `key`. O(1).
     *
     * Requirements:
     *
     * - `key` must be in the map.
     */
    function get(UintToAddressMap storage map, uint256 key) internal view returns (address) {
        return address(uint160(uint256(get(map._inner, bytes32(key)))));
    }

    /**
     * @dev Same as {get}, with a custom error message when `key` is not in the map.
     *
     * CAUTION: This function is deprecated because it requires allocating memory for the error
     * message unnecessarily. For custom revert reasons use {tryGet}.
     */
    function get(
        UintToAddressMap storage map,
        uint256 key,
        string memory errorMessage
    ) internal view returns (address) {
        return address(uint160(uint256(get(map._inner, bytes32(key), errorMessage))));
    }

    // AddressToUintMap

    struct AddressToUintMap {
        Bytes32ToBytes32Map _inner;
    }

    /**
     * @dev Adds a key-value pair to a map, or updates the value for an existing
     * key. O(1).
     *
     * Returns true if the key was added to the map, that is if it was not
     * already present.
     */
    function set(
        AddressToUintMap storage map,
        address key,
        uint256 value
    ) internal returns (bool) {
        return set(map._inner, bytes32(uint256(uint160(key))), bytes32(value));
    }

    /**
     * @dev Removes a value from a set. O(1).
     *
     * Returns true if the key was removed from the map, that is if it was present.
     */
    function remove(AddressToUintMap storage map, address key) internal returns (bool) {
        return remove(map._inner, bytes32(uint256(uint160(key))));
    }

    /**
     * @dev Returns true if the key is in the map. O(1).
     */
    function contains(AddressToUintMap storage map, address key) internal view returns (bool) {
        return contains(map._inner, bytes32(uint256(uint160(key))));
    }

    /**
     * @dev Returns the number of elements in the map. O(1).
     */
    function length(AddressToUintMap storage map) internal view returns (uint256) {
        return length(map._inner);
    }

    /**
     * @dev Returns the element stored at position `index` in the set. O(1).
     * Note that there are no guarantees on the ordering of values inside the
     * array, and it may change when more values are added or removed.
     *
     * Requirements:
     *
     * - `index` must be strictly less than {length}.
     */
    function at(AddressToUintMap storage map, uint256 index) internal view returns (address, uint256) {
        (bytes32 key, bytes32 value) = at(map._inner, index);
        return (address(uint160(uint256(key))), uint256(value));
    }

    /**
     * @dev Tries to returns the value associated with `key`. O(1).
     * Does not revert if `key` is not in the map.
     */
    function tryGet(AddressToUintMap storage map, address key) internal view returns (bool, uint256) {
        (bool success, bytes32 value) = tryGet(map._inner, bytes32(uint256(uint160(key))));
        return (success, uint256(value));
    }

    /**
     * @dev Returns the value associated with `key`. O(1).
     *
     * Requirements:
     *
     * - `key` must be in the map.
     */
    function get(AddressToUintMap storage map, address key) internal view returns (uint256) {
        return uint256(get(map._inner, bytes32(uint256(uint160(key)))));
    }

    /**
     * @dev Same as {get}, with a custom error message when `key` is not in the map.
     *
     * CAUTION: This function is deprecated because it requires allocating memory for the error
     * message unnecessarily. For custom revert reasons use {tryGet}.
     */
    function get(
        AddressToUintMap storage map,
        address key,
        string memory errorMessage
    ) internal view returns (uint256) {
        return uint256(get(map._inner, bytes32(uint256(uint160(key))), errorMessage));
    }

    // Bytes32ToUintMap

    struct Bytes32ToUintMap {
        Bytes32ToBytes32Map _inner;
    }

    /**
     * @dev Adds a key-value pair to a map, or updates the value for an existing
     * key. O(1).
     *
     * Returns true if the key was added to the map, that is if it was not
     * already present.
     */
    function set(
        Bytes32ToUintMap storage map,
        bytes32 key,
        uint256 value
    ) internal returns (bool) {
        return set(map._inner, key, bytes32(value));
    }

    /**
     * @dev Removes a value from a set. O(1).
     *
     * Returns true if the key was removed from the map, that is if it was present.
     */
    function remove(Bytes32ToUintMap storage map, bytes32 key) internal returns (bool) {
        return remove(map._inner, key);
    }

    /**
     * @dev Returns true if the key is in the map. O(1).
     */
    function contains(Bytes32ToUintMap storage map, bytes32 key) internal view returns (bool) {
        return contains(map._inner, key);
    }

    /**
     * @dev Returns the number of elements in the map. O(1).
     */
    function length(Bytes32ToUintMap storage map) internal view returns (uint256) {
        return length(map._inner);
    }

    /**
     * @dev Returns the element stored at position `index` in the set. O(1).
     * Note that there are no guarantees on the ordering of values inside the
     * array, and it may change when more values are added or removed.
     *
     * Requirements:
     *
     * - `index` must be strictly less than {length}.
     */
    function at(Bytes32ToUintMap storage map, uint256 index) internal view returns (bytes32, uint256) {
        (bytes32 key, bytes32 value) = at(map._inner, index);
        return (key, uint256(value));
    }

    /**
     * @dev Tries to returns the value associated with `key`. O(1).
     * Does not revert if `key` is not in the map.
     */
    function tryGet(Bytes32ToUintMap storage map, bytes32 key) internal view returns (bool, uint256) {
        (bool success, bytes32 value) = tryGet(map._inner, key);
        return (success, uint256(value));
    }

    /**
     * @dev Returns the value associated with `key`. O(1).
     *
     * Requirements:
     *
     * - `key` must be in the map.
     */
    function get(Bytes32ToUintMap storage map, bytes32 key) internal view returns (uint256) {
        return uint256(get(map._inner, key));
    }

    /**
     * @dev Same as {get}, with a custom error message when `key` is not in the map.
     *
     * CAUTION: This function is deprecated because it requires allocating memory for the error
     * message unnecessarily. For custom revert reasons use {tryGet}.
     */
    function get(
        Bytes32ToUintMap storage map,
        bytes32 key,
        string memory errorMessage
    ) internal view returns (uint256) {
        return uint256(get(map._inner, key, errorMessage));
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.8.0) (security/ReentrancyGuard.sol)

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
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.12;

import {
    Position, 
    OrderInfo, 
    OrderType, 
    DataType, 
    OrderStatus
} from "../../constants/Structs.sol";

interface IPositionKeeper {
    function poolAmounts(address _token, bool _isLong) external view returns (uint256);

    function reservedAmounts(address _token, bool _isLong) external view returns (uint256);

    function openNewPosition(
        bytes32 _key,
        bool _isLong, 
        uint256 _posId,
        address[] memory _path,
        uint256[] memory _params,
        bytes memory _data
    ) external;

    function unpackAndStorage(bytes32 _key, bytes memory _data, DataType _dataType) external;

    function deletePosition(bytes32 _key) external;

    function increaseReservedAmount(address _token, bool _isLong, uint256 _amount) external;

    function decreaseReservedAmount(address _token, bool _isLong, uint256 _amount) external;

    function increasePoolAmount(address _indexToken, bool _isLong, uint256 _amount) external;

    function decreasePoolAmount(address _indexToken, bool _isLong, uint256 _amount) external;

    //Emit event functions
    function emitAddPositionEvent(
        bytes32 key, 
        bool confirmDelayStatus, 
        uint256 collateral, 
        uint256 size
    ) external;

    function emitAddOrRemoveCollateralEvent(
        bytes32 _key,
        bool _isPlus,
        uint256 _amount,
        uint256 _reserveAmount,
        uint256 _collateral,
        uint256 _size
    ) external;

    function emitAddTrailingStopEvent(bytes32 _key, uint256[] memory data) external;

    function emitUpdateTrailingStopEvent(bytes32 _key, uint256 _stpPrice) external;

    function emitUpdateOrderEvent(bytes32 _key, uint256 _positionType, OrderStatus _orderStatus) external;

    function emitConfirmDelayTransactionEvent(
        bytes32 _key,
        bool _confirmDelayStatus,
        uint256 _collateral,
        uint256 _size,
        uint256 _feeUsd
    ) external;

    function emitPositionExecutedEvent(
        bytes32 _key,
        address _account,
        address _indexToken,
        bool _isLong,
        uint256 _posId,
        uint256[] memory _prices
    ) external;

    function emitIncreasePositionEvent(
        address _account,
        address _indexToken,
        bool _isLong,
        uint256 _posId,
        uint256 _collateralDelta,
        uint256 _sizeDelta,
        uint256 _fee,
        uint256 _indexPrice
    ) external;

    function emitClosePositionEvent(
        address _account, 
        address _indexToken, 
        bool _isLong, 
        uint256 _posId, 
        uint256 _indexPrice
    ) external;

    function emitDecreasePositionEvent(
        address _account,
        address _indexToken,
        bool _isLong,
        uint256 _posId,
        uint256 _sizeDelta,
        uint256 _fee,
        uint256 _indexPrice
    ) external;

    function emitLiquidatePositionEvent(
        address _account, 
        address _indexToken, 
        bool _isLong, 
        uint256 _posId, 
        uint256 _indexPrice
    ) external;

    //View functions
    function getPositions(
        address _account,
        address _indexToken,
        bool _isLong,
        uint256 _posId
    ) external view returns (Position memory, OrderInfo memory);

    function getPositions(bytes32 _key) external view returns (Position memory, OrderInfo memory);

    function getPosition(
        address _account,
        address _indexToken,
        bool _isLong,
        uint256 _posId
    ) external view returns (Position memory);

    function getPosition(bytes32 _key) external view returns (Position memory);

    function getOrder(bytes32 _key) external view returns (OrderInfo memory);

    function getPositionFee(bytes32 _key) external view returns (uint256);

    function getPositionOwner(bytes32 _key) external view returns (address);

    function getPositionCollateralToken(bytes32 _key) external view returns (address);

    function lastPositionIndex(address _account) external view returns (uint256);
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.12;

import {Position, PositionBond, OrderInfo, OrderType} from "../../constants/Structs.sol";

interface IPositionHandler {
    function getBond(bytes32 _key) external view returns (PositionBond memory);

    function openNewPosition(
        bytes32 _key,
        bool _isLong, 
        uint256 _posId,
        bytes memory _data,
        uint256[] memory _params,
        uint256[] memory _prices, 
        address[] memory _path,
        bool _isDirectExecuted
    ) external;

    function modifyPosition(
        bytes32 _key, 
        uint256 _txType, 
        bytes memory _data,
        address[] memory path,
        uint256[] memory prices
    ) external;

    function setPriceAndExecuteInBatch(
        bytes32[] memory _keys, 
        bool[] memory _isLiquidates, 
        address[][] memory _batchPath,
        uint256[][] memory _batchPrices
    ) external;
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.12;

interface IPriceManager {
    function getDelta(
        address _indexToken,
        uint256 _size,
        uint256 _averagePrice,
        bool _isLong,
        uint256 _indexPrice
    ) external view returns (bool, uint256);

    function getLastPrice(address _token) external view returns (uint256);

    function getLatestSynchronizedPrice(address _token) external view returns (uint256, uint256, bool);

    function getLatestSynchronizedPrices(uint256 _maxDelayAllowance, address[] memory _tokens) external view returns (uint256[] memory, bool);

    function setLatestPrice(address _token, uint256 _latestPrice) external;

    function getNextAveragePrice(
        address _indexToken,
        uint256 _size,
        uint256 _averagePrice,
        bool _isLong,
        uint256 _nextPrice,
        uint256 _sizeDelta
    ) external view returns (uint256);

    function isForex(address _token) external view returns (bool);

    function maxLeverage(address _token) external view returns (uint256);

    function tokenDecimals(address _token) external view returns (uint256);

    function fromUSDToToken(address _token, uint256 _usdAmount) external view returns (uint256);

    function fromTokenToUSD(address _token, uint256 _tokenAmount) external view returns (uint256);
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.12;

interface ISettingsManager {
    function decreaseOpenInterest(address _token, address _sender, bool _isLong, uint256 _amount) external;

    function increaseOpenInterest(address _token, address _sender, bool _isLong, uint256 _amount) external;

    function updateCumulativeFundingRate(address _token, bool _isLong) external;

    function openInterestPerAsset(address _token) external view returns (uint256);

    function openInterestPerSide(bool _isLong) external view returns (uint256);

    function openInterestPerUser(address _sender) external view returns (uint256);

    function bountyPercent() external view returns (uint256);

    function checkDelegation(address _master, address _delegate) external view returns (bool);

    function closeDeltaTime() external view returns (uint256);

    function collectMarginFees(
        address _account,
        address _indexToken,
        bool _isLong,
        uint256 _sizeDelta,
        uint256 _size,
        uint256 _entryFundingRate
    ) external view returns (uint256);

    function cooldownDuration() external view returns (uint256);

    function cumulativeFundingRates(address _token, bool _isLong) external view returns (uint256);

    function delayDeltaTime() external view returns (uint256);

    function depositFee() external view returns (uint256);

    function feeManager() external view returns (address);

    function feeRewardBasisPoints() external view returns (uint256);

    function fundingInterval() external view returns (uint256);

    function fundingRateFactor(address _token, bool _isLong) external view returns (uint256);

    function getFundingFee(
        address _indexToken,
        bool _isLong,
        uint256 _size,
        uint256 _entryFundingRate
    ) external view returns (uint256);

    function getPositionFee(address _indexToken, bool _isLong, uint256 _sizeDelta) external view returns (uint256);

    function getDelegates(address _master) external view returns (address[] memory);

    function isCollateral(address _token) external view returns (bool);

    function isTradable(address _token) external view returns (bool);

    function isStable(address _token) external view returns (bool);

    function isManager(address _account) external view returns (bool);

    function isStaking(address _token) external view returns (bool);

    function lastFundingTimes(address _token, bool _isLong) external view returns (uint256);

    function maxPriceUpdatedDelay() external view returns (uint256);

    function liquidationFeeUsd() external view returns (uint256);

    function liquidateThreshold(address) external view returns (uint256);

    function marginFeeBasisPoints(address _token, bool _isLong) external view returns (uint256);

    function marketOrderEnabled() external view returns (bool);
    
    function pauseForexForCloseTime() external view returns (bool);

    function priceMovementPercent() external view returns (uint256);

    function referFee() external view returns (uint256);

    function referEnabled() external view returns (bool);

    function stakingFee() external view returns (uint256);

    function unstakingFee() external view returns (uint256);

    function triggerGasFee() external view returns (uint256);

    function positionDefaultSlippage() external view returns (uint256);

    function setPositionDefaultSlippage(uint256 _slippage) external;

    function isOnBeta() external view returns (bool);

    function isEnableNonStableCollateral() external view returns (bool);

    function isEnableConvertRUSD() external view returns (bool);

    function isEnableUnstaking() external view returns (bool);

    function validatePosition(
        address _account,
        address _indexToken,
        bool _isLong,
        uint256 _size,
        uint256 _collateral
    ) external view;
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.12;

interface IVault {
    function accountDeltaAndFeeIntoTotalBalance(
        bool _hasProfit, 
        uint256 _adjustDelta, 
        uint256 _fee,
        address _token
    ) external;

    function distributeFee(address _account, address _refer, uint256 _fee, address _token) external;

    function takeAssetIn(
        address _account, 
        address _refer, 
        uint256 _amount, 
        uint256 _fee, 
        address _token
    ) external;

    function takeAssetOut(
        address _account, 
        address _refer, 
        uint256 _fee, 
        uint256 _usdOut, 
        address _token, 
        uint256 _tokenPrice
    ) external;

    function transferBounty(
        address _account, 
        uint256 _amount, 
        address _token, 
        uint256 _tokenPrice
    ) external;

    function ROLP() external view returns(address);

    function RUSD() external view returns(address);

    function totalUSD() external view returns(uint256);

    function totalROLP() external view returns(uint256);

    function updateTotalROLP() external;

    function updateBalance(address _token) external;

    function updateBalances() external;

    function getBalance(address _token) external view returns (uint256);

    function getBalances() external view returns (address[] memory, uint256[] memory);

    function convertRUSD(
        address _account,
        address _recipient, 
        address _tokenOut, 
        uint256 _amount
    ) external;

    function stake(address _account, address _token, uint256 _amount) external;

    function unstake(address _tokenOut, uint256 _rolpAmount, address _receiver) external;

    function emergencyDeposit(address _token, uint256 _amount) external;
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.12;

import {OrderInfo, OrderType} from "../../constants/Structs.sol";

interface IVaultUtils {
    function validateConfirmDelay(
        address _account,
        address _indexToken,
        bool _isLong,
        uint256 _posId,
        bool _raise
    ) external view returns (bool);

    function validateDecreasePosition(
        address _account,
        address _indexToken,
        bool _isLong,
        uint256 _posId,
        bool _raise,
        uint256 _indexPrice
    ) external view returns (bool);

    function validateLiquidation(
        address _account,
        address _indexToken,
        bool _isLong,
        uint256 _posId,
        bool _raise,
        uint256 _indexPrice
    ) external view returns (uint256, uint256);

    function validatePositionData(
        bool _isLong,
        address _indexToken,
        OrderType _orderType,
        uint256 _latestTokenPrice,
        uint256[] memory _params,
        bool _raise
    ) external view returns (bool);

    function validateSizeCollateralAmount(uint256 _size, uint256 _collateral) external view;

    function validateTrailingStopInputData(
        address _account,
        address _indexToken,
        bool _isLong,
        uint256 _posId,
        uint256[] memory _params
    ) external view returns (bool);

    // function validateTrailingStopPrice(
    //     address _account,
    //     address _indexToken,
    //     bool _isLong,
    //     uint256 _posId,
    //     bool _raise,
    //     uint256 _indexPrice
    // ) external view returns (bool);

    function validateTrigger(
        address _account,
        address _indexToken,
        bool _isLong,
        uint256 _posId,
        uint256 _indexPrice
    ) external view returns (uint8);
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.12;

interface ITriggerOrderManager {
    function executeTriggerOrders(
        address _account,
        address _token,
        bool _isLong,
        uint256 _posId,
        uint256 _indexPrice
    ) external returns (bool, uint256);

    function validateTPSLTriggers(
        address _account,
        address _token,
        bool _isLong,
        uint256 _posId
    ) external view returns (bool);
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.12;

import {PrepareTransaction, PositionBond, OrderType} from "../../constants/Structs.sol";

interface IRouter {
    //Write functions

    /*
    @dev: Open new position.
    Path length must between 2 or 3 which:
        path[0] is approved index tradable token,
        path[1] is approved stable token,
        or path[1] is approved collateral token and path[2] is approved stable token. 
        If the collateral token not stable, the first path must be approved collateral and the last path must be approved stable.
    Params length must be 6.
        For all orders: 
        _params[2] is collateral, 
        _params[3] is position size (collateral * leverage),
        _params[4] is deadline (must be bigger than 0), if the transaction is delayed, check this deadline for executing or reverting.
        _params[5] is amount out min if the collateral token is not stable token, we will swap to a stable following path
        Market order:
            _params[0] is mark price
            _params[1] is slippage percentage
        Limit order:
            _params[0] is limit price
            _params[1] must be 0
        Stop-market order:
            _params[0] must be 0
            _params[1] is stop price
        Stop-limit order:
            _params[0] is limit price
            _params[1] is stop price
    */
    function openNewPosition(
        bool _isLong,
        OrderType _orderType,
        address _refer,
        uint256[] memory _params,
        address[] memory _path
    ) external payable;

    function addCollateral(
        bool _isLong,
        uint256 _posId,
        uint256[] memory _params,
        address[] memory _path
    ) external;

    function removeCollateral(
        address _indexToken,
        bool _isLong,
        uint256 _posId,
        uint256 _amount
    ) external;

    function addPosition(
        bool _isLong,
        uint256 _posId,
        uint256[] memory _params,
        address[] memory _path
    ) external payable;

    function addTrailingStop(
        bool _isLong,
        uint256 _posId,
        uint256[] memory _params,
        address[] memory _path
    ) external payable;

    function cancelPendingOrder(
        address _indexToken, 
        bool _isLong, 
        uint256 _posId
    ) external;

    //Params length must be 2, [0] is close size delta, [1] is deadline
    function closePosition(
        address _indexToken,
        bool _isLong,
        uint256 _posId,
        uint256[] memory _params
    ) external;

    function setPriceAndExecute(
        bytes32 _key, 
        bool _isLiquidate,
        uint256[] memory _prices
    ) external;

    //View functions
    function getTransaction(bytes32 _key) external view returns (PrepareTransaction memory);

    function getBond(bytes32 _key) external view returns (PositionBond memory);
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.12;

interface ISwapRouter {
    function swapFromInternal(
        bytes32 _key,
        address _tokenIn, 
        uint256 _amountIn, 
        address _tokenOut,
        uint256 _amountOutMin
    ) external returns (uint256);

    function swap(
        address _tokenIn, 
        uint256 _amountIn, 
        address _tokenOut, 
        address _receiver, 
        uint256 _amountOutMin 
    ) external returns (uint256);
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.12;

import "./BasePositionConstants.sol";

contract PositionConstants is BasePositionConstants {
    uint8 public constant ORDER_FILLED = 1;

    uint256 public constant TRAILING_STOP_TYPE_AMOUNT = 0;
    uint256 public constant TRAILING_STOP_TYPE_PERCENT = 1;

    uint256 public constant LIQUIDATE_NONE_EXCEED = 0;
    uint256 public constant LIQUIDATE_FEE_EXCEED = 1;
    uint256 public constant LIQUIDATE_THRESHOLD_EXCEED = 2;

    function checkSlippage(
        bool isLong,
        uint256 expectedMarketPrice,
        uint256 slippageBasisPoints,
        uint256 actualMarketPrice
    ) internal pure returns (bool) {
        return isLong 
            ? (actualMarketPrice <=
                    (expectedMarketPrice * (BASIS_POINTS_DIVISOR + slippageBasisPoints)) / BASIS_POINTS_DIVISOR)
            : ((expectedMarketPrice * (BASIS_POINTS_DIVISOR - slippageBasisPoints)) / BASIS_POINTS_DIVISOR <=
                    actualMarketPrice);
    }
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.12;

enum OrderType {
    MARKET,
    LIMIT,
    STOP,
    STOP_LIMIT,
    TRAILING_STOP
}

enum OrderStatus {
    NONE,
    PENDING,
    FILLED,
    CANCELED
}

enum TriggerStatus {
    OPEN,
    TRIGGERED,
    CANCELLED
}

enum DataType {
    POSITION,
    ORDER,
    TRANSACTION
}

struct OrderInfo {
    OrderStatus status;
    uint256 lmtPrice;
    uint256 pendingSize;
    uint256 pendingCollateral;
    uint256 positionType;
    uint256 stepAmount;
    uint256 stepType;
    uint256 stpPrice;
    uint256 amountOutMin;
    address collateralToken;
}

struct Position {
    address owner;
    address refer;
    int256 realisedPnl;
    uint256 averagePrice;
    uint256 collateral;
    uint256 entryFundingRate;
    uint256 lastIncreasedTime;
    uint256 lastPrice;
    uint256 reserveAmount;
    uint256 size;
    uint256 deadline;
    uint256 slippage;
    uint256 totalFee;
}

struct TriggerOrder {
    bytes32 key;
    uint256[] slPrices;
    uint256[] slAmountPercents;
    uint256[] slTriggeredAmounts;
    uint256[] tpPrices;
    uint256[] tpAmountPercents;
    uint256[] tpTriggeredAmounts;
    TriggerStatus status;
}

struct ConvertOrder {
    uint256 index;
    address indexToken;
    address sender;
    address recipient;
    uint256 amountIn;
    uint256 amountOut;
    uint256 state;
}

struct SwapPath {
    address pairAddress;
    uint256 fee;
}

struct SwapRequest {
    bytes32 orderKey;
    address tokenIn;
    address pool;
    uint256 amountIn;
}

struct PrepareTransaction {
    uint256 txType;
    uint256 startTime;
    uint256 status; //0 = pending, 1 = executed
    uint256 deadline;
    uint256 amountOutMin;
    uint256[] params;
    address[] path;
}

struct PositionBond {
    address owner;
    address indexToken;
    address token; //Collateral token
    uint256 amount; //Collateral amount
    uint256 leverage;
    uint256 posId;
    bool isLong;
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (token/ERC20/extensions/draft-IERC20Permit.sol)

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
// OpenZeppelin Contracts (last updated v4.8.0) (utils/structs/EnumerableSet.sol)
// This file was procedurally generated from scripts/generate/templates/EnumerableSet.js.

pragma solidity ^0.8.0;

/**
 * @dev Library for managing
 * https://en.wikipedia.org/wiki/Set_(abstract_data_type)[sets] of primitive
 * types.
 *
 * Sets have the following properties:
 *
 * - Elements are added, removed, and checked for existence in constant time
 * (O(1)).
 * - Elements are enumerated in O(n). No guarantees are made on the ordering.
 *
 * ```
 * contract Example {
 *     // Add the library methods
 *     using EnumerableSet for EnumerableSet.AddressSet;
 *
 *     // Declare a set state variable
 *     EnumerableSet.AddressSet private mySet;
 * }
 * ```
 *
 * As of v3.3.0, sets of type `bytes32` (`Bytes32Set`), `address` (`AddressSet`)
 * and `uint256` (`UintSet`) are supported.
 *
 * [WARNING]
 * ====
 * Trying to delete such a structure from storage will likely result in data corruption, rendering the structure
 * unusable.
 * See https://github.com/ethereum/solidity/pull/11843[ethereum/solidity#11843] for more info.
 *
 * In order to clean an EnumerableSet, you can either remove all elements one by one or create a fresh instance using an
 * array of EnumerableSet.
 * ====
 */
library EnumerableSet {
    // To implement this library for multiple types with as little code
    // repetition as possible, we write it in terms of a generic Set type with
    // bytes32 values.
    // The Set implementation uses private functions, and user-facing
    // implementations (such as AddressSet) are just wrappers around the
    // underlying Set.
    // This means that we can only create new EnumerableSets for types that fit
    // in bytes32.

    struct Set {
        // Storage of set values
        bytes32[] _values;
        // Position of the value in the `values` array, plus 1 because index 0
        // means a value is not in the set.
        mapping(bytes32 => uint256) _indexes;
    }

    /**
     * @dev Add a value to a set. O(1).
     *
     * Returns true if the value was added to the set, that is if it was not
     * already present.
     */
    function _add(Set storage set, bytes32 value) private returns (bool) {
        if (!_contains(set, value)) {
            set._values.push(value);
            // The value is stored at length-1, but we add 1 to all indexes
            // and use 0 as a sentinel value
            set._indexes[value] = set._values.length;
            return true;
        } else {
            return false;
        }
    }

    /**
     * @dev Removes a value from a set. O(1).
     *
     * Returns true if the value was removed from the set, that is if it was
     * present.
     */
    function _remove(Set storage set, bytes32 value) private returns (bool) {
        // We read and store the value's index to prevent multiple reads from the same storage slot
        uint256 valueIndex = set._indexes[value];

        if (valueIndex != 0) {
            // Equivalent to contains(set, value)
            // To delete an element from the _values array in O(1), we swap the element to delete with the last one in
            // the array, and then remove the last element (sometimes called as 'swap and pop').
            // This modifies the order of the array, as noted in {at}.

            uint256 toDeleteIndex = valueIndex - 1;
            uint256 lastIndex = set._values.length - 1;

            if (lastIndex != toDeleteIndex) {
                bytes32 lastValue = set._values[lastIndex];

                // Move the last value to the index where the value to delete is
                set._values[toDeleteIndex] = lastValue;
                // Update the index for the moved value
                set._indexes[lastValue] = valueIndex; // Replace lastValue's index to valueIndex
            }

            // Delete the slot where the moved value was stored
            set._values.pop();

            // Delete the index for the deleted slot
            delete set._indexes[value];

            return true;
        } else {
            return false;
        }
    }

    /**
     * @dev Returns true if the value is in the set. O(1).
     */
    function _contains(Set storage set, bytes32 value) private view returns (bool) {
        return set._indexes[value] != 0;
    }

    /**
     * @dev Returns the number of values on the set. O(1).
     */
    function _length(Set storage set) private view returns (uint256) {
        return set._values.length;
    }

    /**
     * @dev Returns the value stored at position `index` in the set. O(1).
     *
     * Note that there are no guarantees on the ordering of values inside the
     * array, and it may change when more values are added or removed.
     *
     * Requirements:
     *
     * - `index` must be strictly less than {length}.
     */
    function _at(Set storage set, uint256 index) private view returns (bytes32) {
        return set._values[index];
    }

    /**
     * @dev Return the entire set in an array
     *
     * WARNING: This operation will copy the entire storage to memory, which can be quite expensive. This is designed
     * to mostly be used by view accessors that are queried without any gas fees. Developers should keep in mind that
     * this function has an unbounded cost, and using it as part of a state-changing function may render the function
     * uncallable if the set grows to a point where copying to memory consumes too much gas to fit in a block.
     */
    function _values(Set storage set) private view returns (bytes32[] memory) {
        return set._values;
    }

    // Bytes32Set

    struct Bytes32Set {
        Set _inner;
    }

    /**
     * @dev Add a value to a set. O(1).
     *
     * Returns true if the value was added to the set, that is if it was not
     * already present.
     */
    function add(Bytes32Set storage set, bytes32 value) internal returns (bool) {
        return _add(set._inner, value);
    }

    /**
     * @dev Removes a value from a set. O(1).
     *
     * Returns true if the value was removed from the set, that is if it was
     * present.
     */
    function remove(Bytes32Set storage set, bytes32 value) internal returns (bool) {
        return _remove(set._inner, value);
    }

    /**
     * @dev Returns true if the value is in the set. O(1).
     */
    function contains(Bytes32Set storage set, bytes32 value) internal view returns (bool) {
        return _contains(set._inner, value);
    }

    /**
     * @dev Returns the number of values in the set. O(1).
     */
    function length(Bytes32Set storage set) internal view returns (uint256) {
        return _length(set._inner);
    }

    /**
     * @dev Returns the value stored at position `index` in the set. O(1).
     *
     * Note that there are no guarantees on the ordering of values inside the
     * array, and it may change when more values are added or removed.
     *
     * Requirements:
     *
     * - `index` must be strictly less than {length}.
     */
    function at(Bytes32Set storage set, uint256 index) internal view returns (bytes32) {
        return _at(set._inner, index);
    }

    /**
     * @dev Return the entire set in an array
     *
     * WARNING: This operation will copy the entire storage to memory, which can be quite expensive. This is designed
     * to mostly be used by view accessors that are queried without any gas fees. Developers should keep in mind that
     * this function has an unbounded cost, and using it as part of a state-changing function may render the function
     * uncallable if the set grows to a point where copying to memory consumes too much gas to fit in a block.
     */
    function values(Bytes32Set storage set) internal view returns (bytes32[] memory) {
        bytes32[] memory store = _values(set._inner);
        bytes32[] memory result;

        /// @solidity memory-safe-assembly
        assembly {
            result := store
        }

        return result;
    }

    // AddressSet

    struct AddressSet {
        Set _inner;
    }

    /**
     * @dev Add a value to a set. O(1).
     *
     * Returns true if the value was added to the set, that is if it was not
     * already present.
     */
    function add(AddressSet storage set, address value) internal returns (bool) {
        return _add(set._inner, bytes32(uint256(uint160(value))));
    }

    /**
     * @dev Removes a value from a set. O(1).
     *
     * Returns true if the value was removed from the set, that is if it was
     * present.
     */
    function remove(AddressSet storage set, address value) internal returns (bool) {
        return _remove(set._inner, bytes32(uint256(uint160(value))));
    }

    /**
     * @dev Returns true if the value is in the set. O(1).
     */
    function contains(AddressSet storage set, address value) internal view returns (bool) {
        return _contains(set._inner, bytes32(uint256(uint160(value))));
    }

    /**
     * @dev Returns the number of values in the set. O(1).
     */
    function length(AddressSet storage set) internal view returns (uint256) {
        return _length(set._inner);
    }

    /**
     * @dev Returns the value stored at position `index` in the set. O(1).
     *
     * Note that there are no guarantees on the ordering of values inside the
     * array, and it may change when more values are added or removed.
     *
     * Requirements:
     *
     * - `index` must be strictly less than {length}.
     */
    function at(AddressSet storage set, uint256 index) internal view returns (address) {
        return address(uint160(uint256(_at(set._inner, index))));
    }

    /**
     * @dev Return the entire set in an array
     *
     * WARNING: This operation will copy the entire storage to memory, which can be quite expensive. This is designed
     * to mostly be used by view accessors that are queried without any gas fees. Developers should keep in mind that
     * this function has an unbounded cost, and using it as part of a state-changing function may render the function
     * uncallable if the set grows to a point where copying to memory consumes too much gas to fit in a block.
     */
    function values(AddressSet storage set) internal view returns (address[] memory) {
        bytes32[] memory store = _values(set._inner);
        address[] memory result;

        /// @solidity memory-safe-assembly
        assembly {
            result := store
        }

        return result;
    }

    // UintSet

    struct UintSet {
        Set _inner;
    }

    /**
     * @dev Add a value to a set. O(1).
     *
     * Returns true if the value was added to the set, that is if it was not
     * already present.
     */
    function add(UintSet storage set, uint256 value) internal returns (bool) {
        return _add(set._inner, bytes32(value));
    }

    /**
     * @dev Removes a value from a set. O(1).
     *
     * Returns true if the value was removed from the set, that is if it was
     * present.
     */
    function remove(UintSet storage set, uint256 value) internal returns (bool) {
        return _remove(set._inner, bytes32(value));
    }

    /**
     * @dev Returns true if the value is in the set. O(1).
     */
    function contains(UintSet storage set, uint256 value) internal view returns (bool) {
        return _contains(set._inner, bytes32(value));
    }

    /**
     * @dev Returns the number of values in the set. O(1).
     */
    function length(UintSet storage set) internal view returns (uint256) {
        return _length(set._inner);
    }

    /**
     * @dev Returns the value stored at position `index` in the set. O(1).
     *
     * Note that there are no guarantees on the ordering of values inside the
     * array, and it may change when more values are added or removed.
     *
     * Requirements:
     *
     * - `index` must be strictly less than {length}.
     */
    function at(UintSet storage set, uint256 index) internal view returns (uint256) {
        return uint256(_at(set._inner, index));
    }

    /**
     * @dev Return the entire set in an array
     *
     * WARNING: This operation will copy the entire storage to memory, which can be quite expensive. This is designed
     * to mostly be used by view accessors that are queried without any gas fees. Developers should keep in mind that
     * this function has an unbounded cost, and using it as part of a state-changing function may render the function
     * uncallable if the set grows to a point where copying to memory consumes too much gas to fit in a block.
     */
    function values(UintSet storage set) internal view returns (uint256[] memory) {
        bytes32[] memory store = _values(set._inner);
        uint256[] memory result;

        /// @solidity memory-safe-assembly
        assembly {
            result := store
        }

        return result;
    }
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.12;

contract BasePositionConstants {
    uint256 public constant PRICE_PRECISION = 10 ** 18; //Base on RUSD decimals
    uint256 public constant BASIS_POINTS_DIVISOR = 100000;

    uint256 public constant POSITION_MARKET = 0;
    uint256 public constant POSITION_LIMIT = 1;
    uint256 public constant POSITION_STOP_MARKET = 2;
    uint256 public constant POSITION_STOP_LIMIT = 3;
    uint256 public constant POSITION_TRAILING_STOP = 4;

    uint256 public constant CREATE_POSITION_MARKET = 0;
    uint256 public constant CREATE_POSITION_LIMIT = 1;
    uint256 public constant CREATE_POSITION_STOP_MARKET = 2;
    uint256 public constant CREATE_POSITION_STOP_LIMIT = 3;
    uint256 public constant ADD_COLLATERAL = 4;
    uint256 public constant REMOVE_COLLATERAL = 5;
    uint256 public constant ADD_POSITION = 6;
    uint256 public constant CONFIRM_POSITION = 7;
    uint256 public constant ADD_TRAILING_STOP = 8;
    uint256 public constant UPDATE_TRAILING_STOP = 9;
    uint256 public constant TRIGGER_POSITION = 10;
    uint256 public constant CANCEL_PENDING_ORDER = 11;
    uint256 public constant CLOSE_POSITION = 12;
    uint256 public constant LIQUIDATE_POSITION = 13;

    function _getPositionKey(
        address _account,
        address _indexToken,
        bool _isLong,
        uint256 _posId
    ) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(_account, _indexToken, _isLong, _posId));
    }

    function _cutFrom(address[] memory _arr, uint256 _startIndex) internal pure returns (address[] memory) {
        require(_arr.length > 1 && _arr.length <= 3, "IVLAL");
        address[] memory newArr;

        if (_arr.length == 2 && _startIndex == 1) {
            newArr = new address[](1);
            newArr[0] = _arr[1];
            return newArr;
        }

        require(_startIndex < _arr.length - 1, "IVLAL/S");
        newArr = new address[](_arr.length - _startIndex);
        uint256 count = 0;

        for (uint256 i = _startIndex; i < _arr.length; i++) {
            newArr[count] = _arr[i];
            count++;
        }

        return newArr;
    }
}