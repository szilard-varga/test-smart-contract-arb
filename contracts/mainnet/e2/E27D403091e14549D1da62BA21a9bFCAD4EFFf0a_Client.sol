// SPDX-License-Identifier: MIT

pragma solidity >=0.8.0 <0.9.0;

contract Client {

    address public immutable broker;

    constructor (address broker_) {
        broker = broker_;
    }

    receive() external payable {}

    fallback() external payable {
        address imp = IBroker(broker).clientImplementation();
        assembly {
            calldatacopy(0, 0, calldatasize())
            let result := delegatecall(gas(), imp, 0, calldatasize(), 0, 0)
            returndatacopy(0, 0, returndatasize())
            switch result
            case 0 { revert(0, returndatasize()) }
            default { return(0, returndatasize()) }
        }
    }

}

interface IBroker {
    function clientImplementation() external view returns (address);
}