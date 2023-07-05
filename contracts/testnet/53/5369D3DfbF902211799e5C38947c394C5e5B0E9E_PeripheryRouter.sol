//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

// --------------------------------------------------------------------------------
// --------------------------------------------------------------------------------
// GENERATED CODE - do not edit manually!!
// --------------------------------------------------------------------------------
// --------------------------------------------------------------------------------

contract PeripheryRouter {
    error UnknownSelector(bytes4 sel);

    address private constant _OWNER_UPGRADE_MODULE = 0x47412051C12b2A07EFD46Ec9B1e095852549b002;
    address private constant _CONFIGURATION_MODULE = 0x07D6D75CA125a252AEf4d5647198446e5EDc5BBa;
    address private constant _ERC721_RECEIVER_MODULE = 0xf8EEF5826c656ea143396de2a56c0AA27AE4FD38;
    address private constant _EXECUTION_MODULE = 0x1CDfd37FBa2EBF96dDbf5ac2244CF271d8254fD7;

    fallback() external payable {
        // Lookup table: Function selector => implementation contract
        bytes4 sig4 = msg.sig;
        address implementation;

        assembly {
            let sig32 := shr(224, sig4)

            function findImplementation(sig) -> result {
                if lt(sig,0x718fe928) {
                    switch sig
                    case 0x150b7a02 { result := _ERC721_RECEIVER_MODULE } // ERC721ReceiverModule.onERC721Received()
                    case 0x1627540c { result := _OWNER_UPGRADE_MODULE } // OwnerUpgradeModule.nominateNewOwner()
                    case 0x3593564c { result := _EXECUTION_MODULE } // ExecutionModule.execute()
                    case 0x3659cfe6 { result := _OWNER_UPGRADE_MODULE } // OwnerUpgradeModule.upgradeTo()
                    case 0x53a47bb7 { result := _OWNER_UPGRADE_MODULE } // OwnerUpgradeModule.nominatedOwner()
                    case 0x6bd50cef { result := _CONFIGURATION_MODULE } // ConfigurationModule.getConfiguration()
                    leave
                }
                switch sig
                case 0x718fe928 { result := _OWNER_UPGRADE_MODULE } // OwnerUpgradeModule.renounceNomination()
                case 0x79ba5097 { result := _OWNER_UPGRADE_MODULE } // OwnerUpgradeModule.acceptOwnership()
                case 0x8da5cb5b { result := _OWNER_UPGRADE_MODULE } // OwnerUpgradeModule.owner()
                case 0xaaf10f42 { result := _OWNER_UPGRADE_MODULE } // OwnerUpgradeModule.getImplementation()
                case 0xc014fa76 { result := _CONFIGURATION_MODULE } // ConfigurationModule.configure()
                case 0xc7f62cda { result := _OWNER_UPGRADE_MODULE } // OwnerUpgradeModule.simulateUpgradeTo()
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