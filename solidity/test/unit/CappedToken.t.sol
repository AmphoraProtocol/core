// SPDX-License-Identifier: MIT
pragma solidity >=0.8.4 <0.9.0;

import '@contracts/utils/CappedToken.sol';
import {console} from 'forge-std/console.sol';
import {IERC20} from 'isolmate/interfaces/tokens/IERC20.sol';
import {DSTestPlus} from 'solidity-utils/test/DSTestPlus.sol';

abstract contract UnitCappedTokenBase is DSTestPlus {
    IERC20 underlying = IERC20(mockContract(newAddress(), 'underlying'));
    CappedToken cappedToken;

    uint8 constant underlyingDecimals = 6;

    string constant cappedName = 'Underlying Capped Token';
    string constant cappedSymbol = 'cUND';

    address alice = newAddress();

    function setUp() public {
        // Mock decimals call
        vm.mockCall(
            address(underlying), abi.encodeWithSelector(IERC20.decimals.selector), abi.encode(underlyingDecimals)
        );

        // Mock deposit call
        vm.mockCall(address(underlying), abi.encodeWithSelector(IERC20.transferFrom.selector), abi.encode(true));

        // Deploy Capped Token
        cappedToken = new CappedToken();
        cappedToken.initialize(cappedName, cappedSymbol, address(underlying));
    }
}

contract UnitCappedTokenInitialValues is UnitCappedTokenBase {
    function testERC20Metadata() public view {
        assert(keccak256(abi.encodePacked(cappedName)) == keccak256(abi.encodePacked(cappedToken.name())));
        assert(keccak256(abi.encodePacked(cappedSymbol)) == keccak256(abi.encodePacked(cappedToken.symbol())));
        assert(18 == cappedToken.decimals());
    }

    function testGetCap() public view {
        assert(cappedToken.getCap() == 0);
    }

    function testUnderlyingScalar() public view {
        assert(cappedToken.underlyingScalar() == 10 ** (18 - uint256(underlying.decimals())));
    }

    function testUnderlyingAddress() public view {
        assert(cappedToken.underlyingAddress() == address(underlying));
    }

    function testTotalUnderlying() public {
        vm.mockCall(address(underlying), abi.encodeWithSelector(IERC20.balanceOf.selector), abi.encode(0));
        assert(cappedToken.totalUnderlying() == 0);
    }

    function testConvertToShares(uint256 _amount) public {
        vm.assume(_amount != 0);
        vm.assume(_amount < type(uint256).max / cappedToken.underlyingScalar());
        assert(cappedToken.convertToShares(_amount) == _amount * cappedToken.underlyingScalar());
    }

    function testConvertToAssets(uint256 _amount) public {
        vm.assume(_amount != 0);
        vm.assume(_amount > cappedToken.underlyingScalar());
        assert(cappedToken.convertToAssets(_amount) == _amount / cappedToken.underlyingScalar());
    }

    function testPreviewDeposit(uint256 _amount) public {
        vm.assume(_amount != 0);
        vm.assume(_amount < type(uint256).max / cappedToken.underlyingScalar());
        assert(cappedToken.previewDeposit(_amount) == _amount * cappedToken.underlyingScalar());
    }

    function testPreviewMint(uint256 _amount) public {
        vm.assume(_amount != 0);
        vm.assume(_amount > cappedToken.underlyingScalar());
        assert(cappedToken.previewMint(_amount) == _amount / cappedToken.underlyingScalar());
    }

    function testPreviewWithdraw(uint256 _amount) public {
        vm.assume(_amount != 0);
        vm.assume(_amount < type(uint256).max / cappedToken.underlyingScalar());
        assert(cappedToken.previewWithdraw(_amount) == _amount * cappedToken.underlyingScalar());
    }

    function testPreviewRedeem(uint256 _amount) public {
        vm.assume(_amount != 0);
        vm.assume(_amount > cappedToken.underlyingScalar());
        assert(cappedToken.previewMint(_amount) == _amount / cappedToken.underlyingScalar());
    }
}

contract UnitCappedTokenSetCap is UnitCappedTokenBase {
    function testSetCap(uint256 _cap) public {
        cappedToken.setCap(_cap);
        assert(cappedToken.getCap() == _cap);
    }

    function testRevertSetCapOnlyOwner(uint256 _cap) public {
        vm.prank(newAddress());
        vm.expectRevert('Ownable: caller is not the owner');
        cappedToken.setCap(_cap);
    }
}

contract UnitCappedTokenDeposit is UnitCappedTokenBase {
    function testRevertDepositCannotDepositZero() public {
        // set cap
        cappedToken.setCap(type(uint256).max);

        // deposit
        vm.prank(alice);
        vm.expectRevert(ICappedToken.CappedToken_ZeroAmount.selector);
        cappedToken.deposit(0, alice);
    }

    function testRevertDepositCapReached(uint256 _amount) public {
        vm.assume(_amount > 1);
        vm.assume(_amount < type(uint256).max / cappedToken.underlyingScalar());

        uint256 _sharesAmount = cappedToken.convertToShares(_amount - 1);

        // set cap
        cappedToken.setCap(_sharesAmount);

        // deposit
        vm.prank(alice);
        vm.expectRevert(ICappedToken.CappedToken_CapReached.selector);

        cappedToken.deposit(_amount, alice);
    }

    function testDepositMintCappedToken(uint256 _amount) public {
        vm.assume(_amount != 0);
        vm.assume(_amount < type(uint256).max / cappedToken.underlyingScalar());

        uint256 _sharesAmount = cappedToken.convertToShares(_amount);

        // set cap
        cappedToken.setCap(_sharesAmount);

        // deposit
        vm.prank(alice);
        vm.expectCall(
            address(underlying), abi.encodeCall(underlying.transferFrom, (alice, address(cappedToken), _amount))
        );
        cappedToken.deposit(_amount, alice);

        // assert balance
        vm.mockCall(address(underlying), abi.encodeWithSelector(IERC20.balanceOf.selector), abi.encode(0));
        assert(cappedToken.balanceOf(alice) == _sharesAmount);
    }

    function testDepositTransferFrom(uint256 _amount) public {
        vm.assume(_amount != 0);
        vm.assume(_amount < type(uint256).max / cappedToken.underlyingScalar());

        uint256 _sharesAmount = cappedToken.convertToShares(_amount);

        // set cap
        cappedToken.setCap(_sharesAmount);

        // deposit
        vm.prank(alice);
        vm.expectCall(
            address(underlying), abi.encodeCall(underlying.transferFrom, (alice, address(cappedToken), _amount))
        );
        cappedToken.deposit(_amount, alice);
    }
}

contract UnitCappedTokenWithdraw is UnitCappedTokenBase {
    function testRevertWithdrawCannotWithdrawZero() public {
        // withdraw
        vm.prank(alice);
        vm.expectRevert(ICappedToken.CappedToken_ZeroAmount.selector);
        cappedToken.withdraw(0, alice);
    }

    function testWithdrawBurnCappedToken(uint256 _amount) public {
        vm.assume(_amount != 0);
        vm.assume(_amount < type(uint256).max / cappedToken.underlyingScalar());
        deal(address(cappedToken), alice, cappedToken.convertToShares(_amount));

        // withdraw
        vm.prank(alice);
        vm.mockCall(address(underlying), abi.encodeWithSelector(IERC20.transfer.selector), abi.encode(true));
        vm.expectCall(address(underlying), abi.encodeCall(underlying.transfer, (alice, _amount)));
        cappedToken.withdraw(_amount, alice);

        // assert balance
        vm.mockCall(address(underlying), abi.encodeWithSelector(IERC20.balanceOf.selector), abi.encode(_amount));
        assert(cappedToken.balanceOf(alice) == 0);
    }

    function testWithdrawTransfer(uint256 _amount) public {
        vm.assume(_amount != 0);
        vm.assume(_amount < type(uint256).max / cappedToken.underlyingScalar());
        deal(address(cappedToken), alice, cappedToken.convertToShares(_amount));

        // withdraw
        vm.prank(alice);
        vm.mockCall(address(underlying), abi.encodeWithSelector(IERC20.transfer.selector), abi.encode(true));
        vm.expectCall(address(underlying), abi.encodeCall(underlying.transfer, (alice, _amount)));
        cappedToken.withdraw(_amount, alice);
    }
}

contract UnitCappedTokenMint is UnitCappedTokenBase {
    function testMaxMintWithBalanceBiggerThanRemaining(uint256 _amount) public {
        vm.assume(_amount > 1);
        vm.assume(_amount < type(uint256).max / cappedToken.underlyingScalar());

        uint256 _sharesAmount = cappedToken.convertToShares(_amount - 1);

        // set cap
        cappedToken.setCap(_sharesAmount);

        vm.mockCall(
            address(underlying), abi.encodeWithSelector(IERC20.balanceOf.selector, address(cappedToken)), abi.encode(0)
        );
        vm.mockCall(address(underlying), abi.encodeWithSelector(IERC20.balanceOf.selector, alice), abi.encode(_amount));
        assert(cappedToken.maxMint(alice) == _amount - 1);
    }

    function testMaxMintWithBalanceSmallerThanRemaining(uint256 _amount) public {
        vm.assume(_amount > 1);
        vm.assume(_amount < type(uint256).max / cappedToken.underlyingScalar());

        uint256 _sharesAmount = cappedToken.convertToShares(_amount);

        // set cap
        cappedToken.setCap(_sharesAmount);

        vm.mockCall(
            address(underlying), abi.encodeWithSelector(IERC20.balanceOf.selector, address(cappedToken)), abi.encode(0)
        );
        vm.mockCall(
            address(underlying), abi.encodeWithSelector(IERC20.balanceOf.selector, alice), abi.encode(_amount - 1)
        );
        assert(cappedToken.maxMint(alice) == _amount - 1);
    }

    function testMintMintCappedToken(uint256 _amount) public {
        vm.assume(_amount != 0);
        vm.assume(_amount < type(uint256).max / cappedToken.underlyingScalar());

        uint256 _sharesAmount = cappedToken.convertToShares(_amount);

        // set cap
        cappedToken.setCap(_sharesAmount);

        // mint
        vm.prank(alice);
        vm.expectCall(
            address(underlying), abi.encodeCall(underlying.transferFrom, (alice, address(cappedToken), _amount))
        );
        cappedToken.mint(_sharesAmount, alice);

        // assert balance
        vm.mockCall(address(underlying), abi.encodeWithSelector(IERC20.balanceOf.selector), abi.encode(0));
        assert(cappedToken.balanceOf(alice) == _sharesAmount);
    }

    function testMintTransferFrom(uint256 _amount) public {
        vm.assume(_amount != 0);
        vm.assume(_amount < type(uint256).max / cappedToken.underlyingScalar());

        uint256 _sharesAmount = cappedToken.convertToShares(_amount);

        // set cap
        cappedToken.setCap(_sharesAmount);

        // mint
        vm.prank(alice);
        vm.expectCall(
            address(underlying), abi.encodeCall(underlying.transferFrom, (alice, address(cappedToken), _amount))
        );
        cappedToken.mint(_sharesAmount, alice);
    }
}

contract UnitCappedTokenRedeem is UnitCappedTokenBase {
    function testMaxRedeemWithBalanceBiggerThanReceiverShares(uint256 _amount) public {
        vm.assume(_amount > 1);
        vm.assume(_amount < type(uint256).max / cappedToken.underlyingScalar());

        uint256 _sharesAmount = cappedToken.convertToShares(_amount - 1);

        deal(address(cappedToken), alice, _sharesAmount);

        vm.mockCall(
            address(underlying),
            abi.encodeWithSelector(IERC20.balanceOf.selector, address(cappedToken)),
            abi.encode(_amount)
        );
        assert(cappedToken.maxRedeem(alice) == _sharesAmount);
    }

    function testMaxRedeemWithBalanceSmallerThanReceiverShares(uint256 _amount) public {
        vm.assume(_amount > 1);
        vm.assume(_amount < type(uint256).max / cappedToken.underlyingScalar());

        uint256 _sharesAmount = cappedToken.convertToShares(_amount);

        deal(address(cappedToken), alice, _sharesAmount);

        vm.mockCall(
            address(underlying),
            abi.encodeWithSelector(IERC20.balanceOf.selector, address(cappedToken)),
            abi.encode(_amount - 1)
        );
        assert(cappedToken.maxRedeem(alice) == cappedToken.convertToShares(_amount - 1));
    }

    function testRedeemTransfer(uint256 _amount) public {
        vm.assume(_amount > 1);
        vm.assume(_amount < type(uint256).max / cappedToken.underlyingScalar());

        uint256 _sharesAmount = cappedToken.convertToShares(_amount);

        deal(address(cappedToken), alice, _sharesAmount);

        // redeem
        vm.prank(alice);
        vm.mockCall(address(underlying), abi.encodeWithSelector(IERC20.transfer.selector), abi.encode(true));
        cappedToken.redeem(_sharesAmount, alice);
    }
}
