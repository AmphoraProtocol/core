// SPDX-License-Identifier: MIT
pragma solidity >=0.8.4 <0.9.0;

import {BaseInvariant} from '@test/invariant/BaseInvariant.sol';
import {USDA} from '@contracts/core/USDA.sol';
import {USDAHandler} from '@test/handlers/USDAHandler.sol';

contract InvariantUSDA is BaseInvariant {
  USDA public usda;
  USDAHandler public usdaHandler;

  function setUp() public {
    usda = new USDA();
    usdaHandler = new USDAHandler(usda);

    bytes4[] memory _selectors = new bytes4[](12);
    _selectors[0] = USDAHandler.deposit.selector;
    _selectors[1] = USDAHandler.depositTo.selector;
    _selectors[2] = USDAHandler.withdraw.selector;
    _selectors[3] = USDAHandler.withdrawTo.selector;
    _selectors[4] = USDAHandler.withdrawAll.selector;
    _selectors[5] = USDAHandler.withdrawAllTo.selector;
    _selectors[6] = USDAHandler.mint.selector;
    _selectors[7] = USDAHandler.burn.selector;
    _selectors[8] = USDAHandler.recoverDust.selector;
    _selectors[9] = USDAHandler.vaultControllerMint.selector;
    _selectors[10] = USDAHandler.vaultControllerBurn.selector;
    _selectors[11] = USDAHandler.vaultControllerTransfer.selector;

    // _selectors[11] = USDAHandler.donate.selector; // TODO: implement this fn in the handler (also vaultControllerDonate)

    targetSelector(FuzzSelector({addr: address(usdaHandler), selectors: _selectors}));

    targetContract(address(usdaHandler));
  }

  /// @dev the sum of all deposits minus the withdrawals, minus the donated amount should be equal to the total supply of USDA
  function invariant_theSumOfDepositedMinusWithdrawnShouldBeEqualToTotalSupply() public view {
    uint256 _sUSDInTheSystem = usdaHandler.ghost_depositSum() - usdaHandler.ghost_withdrawSum();

    uint256 _totalMintedUsda = usdaHandler.ghost_mintedSum() - usdaHandler.ghost_burnedSum();

    uint256 _usdaTotalSupplyInitialWithoutDonations = usda.totalSupply() - usdaHandler.initialFragmentsSupply();
    uint256 _usdaTotalSupplyInitialWithDonations =
      _usdaTotalSupplyInitialWithoutDonations - usdaHandler.ghost_donatedSum();

    uint256 _totalSupply = _usdaTotalSupplyInitialWithDonations > _totalMintedUsda
      ? _usdaTotalSupplyInitialWithDonations - _totalMintedUsda
      : _totalMintedUsda - _usdaTotalSupplyInitialWithDonations;

    assert(_sUSDInTheSystem == _totalSupply);
  }

  function invariant_callSummary() public view {
    usdaHandler.callSummary();
  }
}
