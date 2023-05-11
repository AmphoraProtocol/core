// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.4 <0.9.0;

import {Deploy, DeployVars} from '@scripts/Deploy.s.sol';
import {IERC20} from '@openzeppelin/contracts/token/ERC20/ERC20.sol';

contract DeployLocal is Deploy {
  address public deployer = vm.rememberKey(vm.envUint('DEPLOYER_ANVIL_LOCAL_PRIVATE_KEY'));

  function run() external {
    vm.startBroadcast(deployer);

    // Deploy weth oracle first, can be removed if the user defines a valid oracle address
    address _oracle = _createWethOracle();

    DeployVars memory _deployVars = DeployVars(
      deployer,
      IERC20(CVX_ADDRESS),
      IERC20(CRV_ADDRESS),
      IERC20(SUSD_ADDRESS),
      IERC20(WETH_ADDRESS),
      BOOSTER,
      _oracle,
      true
    );

    _deploy(_deployVars);
    vm.stopBroadcast();
  }
}
