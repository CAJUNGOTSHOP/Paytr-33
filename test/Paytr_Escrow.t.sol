// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {Test, console2} from "forge-std/Test.sol";
import {Paytr} from "../src/Paytr.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Paytr_Helpers} from "../helpers/Helper_config.sol";

interface IComet {
    function supply(address asset, uint amount) external;
    function withdraw(address asset, uint amount) external;
    function baseToken() external view returns (address);
    function allow(address manager, bool isAllowed) external;
}

contract PaytrTest is Test, Paytr_Helpers {
    using SafeERC20 for IERC20;

    function setUp() public {
        Paytr_Test = new Paytr(
            cometAddress,
            cometWrapperAddress,
            9000,
            7 days,
            365 days,
            10e6,
            30
        );

        vm.label(cometAddress, "Comet");
        vm.label(baseAssetAddress, "USDC");
        vm.label(cometWrapperAddress, "Wrapper Contract");
        vm.label(alice, "alice");
        vm.label(bob, "bob");
        vm.label(charlie, "charlie");
        vm.label(address(this), "Paytr");
        vm.label(0x399F5EE127ce7432E4921a61b8CF52b0af52cbfE, "ERC20FeeProxy contract");

        transferBaseAsset();
        approveBaseAsset();

        Paytr_Test.setERC20FeeProxy(0x399F5EE127ce7432E4921a61b8CF52b0af52cbfE);
    }

    uint256 amountToPay = 100_000e6;

    function test_payInvoiceERC20SingleZeroFeeEscrow() public {

        assert(baseAsset.allowance(alice, address(Paytr_Test)) > amountToPay);

        vm.expectEmit(address(Paytr_Test));        

        emit PaymentERC20Event(baseAssetAddress, bob, dummyFeeAddress, amountToPay, 0, 0, paymentReference1);

        vm.prank(alice);
        Paytr_Test.payInvoiceERC20Escrow(
            bob,
            dummyFeeAddress,
            amountToPay,
            0,
            paymentReference1,
            false
        );
        
        //baseAsset balances
        assertEq(getAlicesBaseAssetBalance(), 50_000_000e6 - amountToPay);
        assertEq(getBobsBaseAssetBalance(), 50_000_000e6);
        assertEq(getCharliesBaseAssetBalance(), 50_000_000e6);
        assertEq(getDummyFeeBaseAssetBalance(), 0);
        assertEq(getContractBaseAssetBalance(), 0);

        //comet (cbaseAssetv3) balances
        assertEq(comet.balanceOf(alice), 0);
        assertEq(comet.balanceOf(bob), 0);
        assertEq(comet.balanceOf(charlie), 0);
        assertEq(comet.balanceOf(dummyFeeAddress), 0);
        assertEq(comet.balanceOf(address(Paytr_Test)), 0);       
        
        //cometWrapper (wcbaseAssetv3) balances
        assertApproxEqRel(getContractCometWrapperBalance(), amountToPay, 0.1e18);

    }

    function test_payInvoiceERC20SingleWithFeeEscrow() public {

        assert(baseAsset.allowance(alice, address(Paytr_Test)) > amountToPay);

        vm.expectEmit(address(Paytr_Test));     

        emit PaymentERC20Event(baseAssetAddress, bob, dummyFeeAddress, amountToPay, 0, 10000, paymentReference1);

        vm.prank(alice);
        Paytr_Test.payInvoiceERC20Escrow(
            bob,
            dummyFeeAddress,
            amountToPay,
            10000,
            paymentReference1,
            false
        );
        
        //baseAsset balances
        assertEq(getAlicesBaseAssetBalance(), 50_000_000e6 - amountToPay - 10000);
        assertEq(getBobsBaseAssetBalance(), 50_000_000e6);
        assertEq(getCharliesBaseAssetBalance(), 50_000_000e6);
        assertEq(getDummyFeeBaseAssetBalance(), 0);
        assertEq(getContractBaseAssetBalance(), 0);

        //comet (cbaseAssetv3) balances
        assertEq(comet.balanceOf(alice), 0);
        assertEq(comet.balanceOf(bob), 0);
        assertEq(comet.balanceOf(charlie), 0);
        assertEq(comet.balanceOf(dummyFeeAddress), 0);
        assertEq(comet.balanceOf(address(Paytr_Test)), 0);       
        
        //cometWrapper (wcbaseAssetv3) balances
        assertApproxEqRel(getContractCometWrapperBalance(), amountToPay + 10000, 0.1e18);

    }

    function test_payAndUpdateSingleZeroFeeEscrow() external {
        assert(baseAsset.allowance(alice, address(Paytr_Test)) > amountToPay);

        vm.expectEmit(address(Paytr_Test));        

        emit PaymentERC20Event(baseAssetAddress, bob, dummyFeeAddress, amountToPay, 0, 0, paymentReference1);

        vm.startPrank(alice);
        Paytr_Test.payInvoiceERC20Escrow(
            bob,
            dummyFeeAddress,
            amountToPay,
            0,
            paymentReference1,
            false
        );

        //baseAsset balances
        assertEq(getAlicesBaseAssetBalance(), 50_000_000e6 - amountToPay);
        assertEq(getBobsBaseAssetBalance(), 50_000_000e6);
        assertEq(getCharliesBaseAssetBalance(), 50_000_000e6);
        assertEq(baseAsset.balanceOf(dummyFeeAddress), 0);
        assertEq(getContractBaseAssetBalance(), 0);
        
        //comet (cbaseAssetv3) balances
        assertEq(comet.balanceOf(alice), 0);
        assertEq(comet.balanceOf(bob), 0);
        assertEq(comet.balanceOf(charlie), 0);
        assertEq(comet.balanceOf(dummyFeeAddress), 0);
        assertEq(comet.balanceOf(address(Paytr_Test)), 0);       
        
        //cometWrapper (wcbaseAssetv3) balances
        assertApproxEqRel(getContractCometWrapperBalance(), amountToPay, 0.1e18);

        vm.warp(block.timestamp + 770 minutes);

        updateDueDate(paymentReference1);
        vm.stopPrank();

        payOutArray = [paymentReference1];

        vm.warp(block.timestamp + 771 minutes);

        //pay out the reference that was just updated
        Paytr_Test.payOutERC20Invoice(payOutArray);

    }

    function test_payInvoiceERC20DoubleEscrow() public {

        assertGt(baseAsset.allowance(alice, address(Paytr_Test)), amountToPay);
        assertGt(baseAsset.allowance(bob, address(Paytr_Test)), amountToPay);

        vm.expectEmit(address(Paytr_Test));        

        emit PaymentERC20Event(baseAssetAddress, bob, dummyFeeAddress, amountToPay, 0, 0, paymentReference1);

        vm.startPrank(alice);
        Paytr_Test.payInvoiceERC20Escrow(
            bob,
            dummyFeeAddress,
            amountToPay,
            0,
            paymentReference1,
            false
        );
        vm.stopPrank();

        //baseAsset balances
        assertEq(getAlicesBaseAssetBalance(), 50_000_000e6 - amountToPay);
        assertEq(getBobsBaseAssetBalance(), 50_000_000e6);
        assertEq(getCharliesBaseAssetBalance(), 50_000_000e6);
        assertEq(baseAsset.balanceOf(dummyFeeAddress), 0);
        assertEq(getContractBaseAssetBalance(), 0);
        
        //comet (cbaseAssetv3) balances
        assertEq(comet.balanceOf(alice), 0);
        assertEq(comet.balanceOf(bob), 0);
        assertEq(comet.balanceOf(charlie), 0);
        assertEq(comet.balanceOf(dummyFeeAddress), 0);
        assertEq(comet.balanceOf(address(Paytr_Test)), 0);       
        
        //cometWrapper (wcbaseAssetv3) balances
        assertApproxEqRel(getContractCometWrapperBalance(), amountToPay, 0.1e18);

        uint256 contractCometWrapperBalanceBeforeSecondPayment = getContractCometWrapperBalance();

        vm.expectEmit(address(Paytr_Test));        

        emit PaymentERC20Event(baseAssetAddress, charlie, dummyFeeAddress, amountToPay, 0, 0, paymentReference2);

        vm.startPrank(bob);
        Paytr_Test.payInvoiceERC20Escrow(
            charlie,
            dummyFeeAddress,
            amountToPay,
            0,
            paymentReference2,
            false
        );
        vm.stopPrank();

        uint256 contractCometWrapperBalanceAfterSecondPayment = getContractCometWrapperBalance();

        //baseAsset balances
        assertEq(getBobsBaseAssetBalance(), 50_000_000e6 - amountToPay);
        assertEq(getCharliesBaseAssetBalance(), 50_000_000e6);
        assertEq(getContractBaseAssetBalance(), 0);

        //comet (cbaseAssetv3) balances
        assertEq(comet.balanceOf(alice), 0);
        assertEq(comet.balanceOf(bob), 0);
        assertEq(comet.balanceOf(charlie), 0);
        assertEq(comet.balanceOf(address(Paytr_Test)), 0);          
        
        //cometWrapper (wcbaseAssetv3) balances
        assertApproxEqRel(contractCometWrapperBalanceAfterSecondPayment, contractCometWrapperBalanceBeforeSecondPayment + amountToPay, 0.1e18);

    }
    
}
