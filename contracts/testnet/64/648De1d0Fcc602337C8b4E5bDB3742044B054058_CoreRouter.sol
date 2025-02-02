//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

// --------------------------------------------------------------------------------
// --------------------------------------------------------------------------------
// GENERATED CODE - do not edit manually!!
// --------------------------------------------------------------------------------
// --------------------------------------------------------------------------------

contract CoreRouter {
    error UnknownSelector(bytes4 sel);

    address private constant _OWNER_UPGRADE_MODULE = 0x98560A91e3b807a5beCD7E21dCbFA2E7aac9c26A;
    address private constant _ACCESS_PASS_CONFIGURATION_MODULE = 0xc553A15D7C33719e5C7B9f8E1BA6E5Fe3997861a;
    address private constant _ACCOUNT_MODULE = 0xcBDbd2DB0a932c0BFe3b65E146645227fb485b87;
    address private constant _ASSOCIATED_SYSTEMS_MODULE = 0x504e98a367F2C1fE05AE754450836dEFa238E165;
    address private constant _COLLATERAL_CONFIGURATION_MODULE = 0xE46A5Adab5dE86adBc52CE64d4ca924da5B4E8f4;
    address private constant _COLLATERAL_MODULE = 0x8FAAA67EeBdCe1887Ef5d4f5579E012BBB9b6f99;
    address private constant _FEATURE_FLAG_MODULE = 0xF93D789c90754629015059C13c0464e71F807E0A;
    address private constant _FEE_CONFIGURATION_MODULE = 0xF43A6536bEdF1dD0fdBF31EBfe4ECD4a89d522F4;
    address private constant _LIQUIDATION_MODULE = 0xCCb17155a554DDF4c93e3F0dbb175ba1DEBB23E8;
    address private constant _PERIPHERY_MODULE = 0x86D6EbBF2eC6B3FE40deb5E2a94B87eEa8613795;
    address private constant _PRODUCT_MODULE = 0xf61356f653027Fb28B4F4351F51bF9a12Ea243fB;
    address private constant _RISK_CONFIGURATION_MODULE = 0x1521B8981f8C0f85db393AF7705222869a9843bc;

    fallback() external payable {
        // Lookup table: Function selector => implementation contract
        bytes4 sig4 = msg.sig;
        address implementation;

        assembly {
            let sig32 := shr(224, sig4)

            function findImplementation(sig) -> result {
                if lt(sig,0x8d34166b) {
                    if lt(sig,0x5f45cf5d) {
                        if lt(sig,0x3659cfe6) {
                            switch sig
                            case 0x00cd9ef3 { result := _ACCOUNT_MODULE } // AccountModule.grantPermission()
                            case 0x0670a130 { result := _RISK_CONFIGURATION_MODULE } // RiskConfigurationModule.getProtocolRiskConfiguration()
                            case 0x1069d4b8 { result := _PRODUCT_MODULE } // ProductModule.getLastCreatedProductId()
                            case 0x117b3e37 { result := _RISK_CONFIGURATION_MODULE } // RiskConfigurationModule.getMarketRiskConfiguration()
                            case 0x1213d453 { result := _ACCOUNT_MODULE } // AccountModule.isAuthorized()
                            case 0x15b3695a { result := _ACCOUNT_MODULE } // AccountModule.onlyAuthorized()
                            case 0x1627540c { result := _OWNER_UPGRADE_MODULE } // OwnerUpgradeModule.nominateNewOwner()
                            case 0x2d22bef9 { result := _ASSOCIATED_SYSTEMS_MODULE } // AssociatedSystemsModule.initOrUpgradeNft()
                            leave
                        }
                        switch sig
                        case 0x3659cfe6 { result := _OWNER_UPGRADE_MODULE } // OwnerUpgradeModule.upgradeTo()
                        case 0x3b969888 { result := _RISK_CONFIGURATION_MODULE } // RiskConfigurationModule.configureMarketRisk()
                        case 0x40a399ef { result := _FEATURE_FLAG_MODULE } // FeatureFlagModule.getFeatureFlagAllowAll()
                        case 0x47c1c561 { result := _ACCOUNT_MODULE } // AccountModule.renouncePermission()
                        case 0x53a47bb7 { result := _OWNER_UPGRADE_MODULE } // OwnerUpgradeModule.nominatedOwner()
                        case 0x5a4066e8 { result := _PRODUCT_MODULE } // ProductModule.getAccountUnrealizedPnL()
                        case 0x5e52ad6e { result := _FEATURE_FLAG_MODULE } // FeatureFlagModule.setFeatureFlagDenyAll()
                        leave
                    }
                    if lt(sig,0x75bf2444) {
                        switch sig
                        case 0x5f45cf5d { result := _PRODUCT_MODULE } // ProductModule.propagateSettlementCashflow()
                        case 0x60988e09 { result := _ASSOCIATED_SYSTEMS_MODULE } // AssociatedSystemsModule.getAssociatedSystem()
                        case 0x61525e71 { result := _LIQUIDATION_MODULE } // LiquidationModule.liquidate()
                        case 0x61cd07a6 { result := _PRODUCT_MODULE } // ProductModule.registerProduct()
                        case 0x6b7d6c94 { result := _COLLATERAL_MODULE } // CollateralModule.getAccountCollateralBalance()
                        case 0x715cb7d2 { result := _FEATURE_FLAG_MODULE } // FeatureFlagModule.setDeniers()
                        case 0x718fe928 { result := _OWNER_UPGRADE_MODULE } // OwnerUpgradeModule.renounceNomination()
                        leave
                    }
                    switch sig
                    case 0x75bf2444 { result := _COLLATERAL_CONFIGURATION_MODULE } // CollateralConfigurationModule.getCollateralConfigurations()
                    case 0x77432aeb { result := _PRODUCT_MODULE } // ProductModule.propagateTakerOrder()
                    case 0x79ba5097 { result := _OWNER_UPGRADE_MODULE } // OwnerUpgradeModule.acceptOwnership()
                    case 0x7d632bd2 { result := _FEATURE_FLAG_MODULE } // FeatureFlagModule.setFeatureFlagAllowAll()
                    case 0x7dec8b55 { result := _ACCOUNT_MODULE } // AccountModule.notifyAccountTransfer()
                    case 0x83802968 { result := _COLLATERAL_MODULE } // CollateralModule.deposit()
                    case 0x89b0c315 { result := _FEE_CONFIGURATION_MODULE } // FeeConfigurationModule.configureMarketFee()
                    leave
                }
                if lt(sig,0xb7746b59) {
                    if lt(sig,0xa32e3038) {
                        switch sig
                        case 0x8d34166b { result := _ACCOUNT_MODULE } // AccountModule.hasPermission()
                        case 0x8da5cb5b { result := _OWNER_UPGRADE_MODULE } // OwnerUpgradeModule.owner()
                        case 0x91734c14 { result := _PRODUCT_MODULE } // ProductModule.closeAccount()
                        case 0x95997c51 { result := _COLLATERAL_MODULE } // CollateralModule.withdraw()
                        case 0x959b1b01 { result := _FEE_CONFIGURATION_MODULE } // FeeConfigurationModule.getMarketFeeConfiguration()
                        case 0x9ee8e198 { result := _ACCOUNT_MODULE } // AccountModule.createAccount()
                        case 0xa0778144 { result := _FEATURE_FLAG_MODULE } // FeatureFlagModule.addToFeatureFlagAllowlist()
                        case 0xa148bf10 { result := _ACCOUNT_MODULE } // AccountModule.getAccountTokenAddress()
                        leave
                    }
                    switch sig
                    case 0xa32e3038 { result := _PRODUCT_MODULE } // ProductModule.getAccountAnnualizedExposures()
                    case 0xa7627288 { result := _ACCOUNT_MODULE } // AccountModule.revokePermission()
                    case 0xa796fecd { result := _ACCOUNT_MODULE } // AccountModule.getAccountPermissions()
                    case 0xaaf10f42 { result := _OWNER_UPGRADE_MODULE } // OwnerUpgradeModule.getImplementation()
                    case 0xad1fd645 { result := _PRODUCT_MODULE } // ProductModule.propagateMakerOrder()
                    case 0xaeb22934 { result := _PERIPHERY_MODULE } // PeripheryModule.setPeriphery()
                    case 0xb68a7ab9 { result := _COLLATERAL_MODULE } // CollateralModule.getAccountCollateralBalanceAvailable()
                    leave
                }
                if lt(sig,0xdc0b3f52) {
                    switch sig
                    case 0xb7746b59 { result := _FEATURE_FLAG_MODULE } // FeatureFlagModule.removeFromFeatureFlagAllowlist()
                    case 0xbcae3ea0 { result := _FEATURE_FLAG_MODULE } // FeatureFlagModule.getFeatureFlagDenyAll()
                    case 0xbf60c31d { result := _ACCOUNT_MODULE } // AccountModule.getAccountOwner()
                    case 0xc7f62cda { result := _OWNER_UPGRADE_MODULE } // OwnerUpgradeModule.simulateUpgradeTo()
                    case 0xcf635949 { result := _FEATURE_FLAG_MODULE } // FeatureFlagModule.isFeatureAllowed()
                    case 0xd7193e8e { result := _COLLATERAL_CONFIGURATION_MODULE } // CollateralConfigurationModule.configureCollateral()
                    case 0xd9c7e37b { result := _COLLATERAL_MODULE } // CollateralModule.getTotalAccountValue()
                    leave
                }
                switch sig
                case 0xdc0b3f52 { result := _COLLATERAL_CONFIGURATION_MODULE } // CollateralConfigurationModule.getCollateralConfiguration()
                case 0xdf2b1369 { result := _RISK_CONFIGURATION_MODULE } // RiskConfigurationModule.configureProtocolRisk()
                case 0xe12c8160 { result := _FEATURE_FLAG_MODULE } // FeatureFlagModule.getFeatureFlagAllowlist()
                case 0xe80bba27 { result := _COLLATERAL_MODULE } // CollateralModule.getAccountLiquidationBoosterBalance()
                case 0xea67af8a { result := _ACCESS_PASS_CONFIGURATION_MODULE } // AccessPassConfigurationModule.configureAccessPass()
                case 0xed429cf7 { result := _FEATURE_FLAG_MODULE } // FeatureFlagModule.getDeniers()
                case 0xf5b3fc29 { result := _ACCESS_PASS_CONFIGURATION_MODULE } // AccessPassConfigurationModule.getAccessPassConfiguration()
                leave
            }

            implementation := findImplementation(sig32)
        }

        if (implementation == address(0)) {
            revert UnknownSelector(sig4);
        }

        // Delegatecall to the implementation contract
        assembly {
            calldatacopy(0, 0, calldatasize())

            let result := delegatecall(gas(), implementation, 0, calldatasize(), 0, 0)
            returndatacopy(0, 0, returndatasize())

            switch result
            case 0 {
                revert(0, returndatasize())
            }
            default {
                return(0, returndatasize())
            }
        }
    }
}