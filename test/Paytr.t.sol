```solidity
// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {Test, console2, Vm} from "forge-std/Test.sol";
import {Paytr} from "../src/Paytr.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Paytr_Helpers} from "../helpers/Helper_config.sol";

interface IComet {
    function supply(address asset, uint amount) external;
    function withdraw(address asset, uint amount) external;
    function baseToken() external view returns (address);
    function allow(address manager, bool isAllowed) external;
    function baseTrackingAccrued(address account) external view returns (uint64);
}

contract PaytrTest is Test, Paytr_Helpers {
    using SafeERC20 for IERC20;

    uint256 amountToPay = 200_000e6;

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

    function test_payInvoiceERC20SingleZeroFee() public {

        assert(baseAsset.allowance(alice, address(Paytr_Test)) > amountToPay);

        vm.expectEmit(true, false, false, true, address(Paytr_Test));

        emit PaymentERC20Event(baseAssetAddress, bob, dummyFeeAddress, amountToPay, uint40(block.timestamp + 10 days), 0, paymentReference1); 

        vm.prank(alice);
        Paytr_Test.payInvoiceERC20(
            bob,
            dummyFeeAddress,
            uint40(block.timestamp + 10 days),
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

    function test_payInvoiceERC20SingleWithFee() public {

        assert(baseAsset.allowance(alice, address(Paytr_Test)) > amountToPay);

        vm.expectEmit(true, false, false, true, address(Paytr_Test));        

        emit PaymentERC20Event(baseAssetAddress, bob, dummyFeeAddress, amountToPay, uint40(block.timestamp + 10 days), 10000, paymentReference1);

        vm.prank(alice);
        Paytr_Test.payInvoiceERC20(
            bob,
            dummyFeeAddress,
            uint40(block.timestamp + 10 days),
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
        assertEq(baseAsset.balanceOf(address(Paytr_Test)), 0);

        //comet (cbaseAssetv3) balances
        assertEq(comet.balanceOf(alice), 0);
        assertEq(comet.balanceOf(bob), 0);
        assertEq(comet.balanceOf(charlie), 0);
        assertEq(comet.balanceOf(dummyFeeAddress), 0);
        assertEq(comet.balanceOf(address(Paytr_Test)), 0);       
        
        //cometWrapper (wcbaseAssetv3) balances
        assertApproxEqRel(getContractCometWrapperBalance(), amountToPay + 10000, 0.1e18);

    }

    function test_payInvoiceERC20Double() public {

        assertGt(baseAsset.allowance(alice, address(Paytr_Test)), amountToPay);
        assertGt(baseAsset.allowance(bob, address(Paytr_Test)), amountToPay);

        vm.expectEmit(true, false, false, true, address(Paytr_Test));        

        emit PaymentERC20Event(baseAssetAddress, bob, dummyFeeAddress, amountToPay, uint40(block.timestamp + 10 days), 0, paymentReference1);

        vm.startPrank(alice);
        Paytr_Test.payInvoiceERC20(
            bob,
            dummyFeeAddress,
            uint40(block.timestamp + 10 days),
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
        assertEq(baseAsset.balanceOf(address(Paytr_Test)), 0);
        
        //comet (cbaseAssetv3) balances
        assertEq(comet.balanceOf(alice), 0);
        assertEq(comet.balanceOf(bob), 0);
        assertEq(comet.balanceOf(charlie), 0);
        assertEq(comet.balanceOf(dummyFeeAddress), 0);
        assertEq(comet.balanceOf(address(Paytr_Test)), 0);       
        
        //cometWrapper (wcbaseAssetv3) balances
        assertApproxEqRel(getContractCometWrapperBalance(), amountToPay, 0.1e18);

        uint256 contractCometWrapperBalanceBeforeSecondPayment = getContractCometWrapperBalance();

        vm.expectEmit(true, false, false, true, address(Paytr_Test));        

        emit PaymentERC20Event(baseAssetAddress, charlie, dummyFeeAddress, amountToPay, uint40(block.timestamp + 10 days), 0, paymentReference2);

        vm.startPrank(bob);
        Paytr_Test.payInvoiceERC20(
            charlie,
            dummyFeeAddress,
            uint40(block.timestamp + 10 days),
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
        assertEq(baseAsset.balanceOf(address(Paytr_Test)), 0);

        //comet (cbaseAssetv3) balances
        assertEq(comet.balanceOf(alice), 0);
        assertEq(comet.balanceOf(bob), 0);
        assertEq(comet.balanceOf(charlie), 0);
        assertEq(comet.balanceOf(address(Paytr_Test)), 0);          
        
        //cometWrapper (wcbaseAssetv3) balances
        assertApproxEqRel(contractCometWrapperBalanceAfterSecondPayment, contractCometWrapperBalanceBeforeSecondPayment + amountToPay, 0.1e18);

    }

    function test_payAndRedeemSingleZeroFee() public {
        assert(baseAsset.allowance(alice, address(Paytr_Test)) > 1000e6);
        vm.expectEmit(true, false, false, true, address(Paytr_Test));       

        emit PaymentERC20Event(baseAssetAddress, bob, dummyFeeAddress, amountToPay, uint40(block.timestamp + 10 days), 0, paymentReference1);

        vm.prank(alice);
        Paytr_Test.payInvoiceERC20(
            bob,
            dummyFeeAddress,
            uint40(block.timestamp + 10 days),
            amountToPay,
            0,
            paymentReference1,
            false
        );

        uint256 aliceBAseAssetBalanceBeforePayOut = getAlicesBaseAssetBalance();
        payOutArray = [paymentReference1];
        
        //increase time to gain interest
        vm.warp(block.timestamp + 20 days);        

        vm.expectEmit(true, false, false, true, address(Paytr_Test));       

        emit PayOutERC20Event(
            baseAssetAddress,
            Paytr_Test.getMapping(paymentReference1).payee,
            Paytr_Test.getMapping(paymentReference1).feeAddress,
            Paytr_Test.getMapping(paymentReference1).amount,
            paymentReference1,
            0
        );
        
        Paytr_Test.payOutERC20Invoice(payOutArray);

        uint256 interestAmount = getAlicesBaseAssetBalance() - aliceBAseAssetBalanceBeforePayOut;
        uint256 expectedAlicesBaseAssetBalance = interestAmount + aliceBAseAssetBalanceBeforePayOut;
        uint256 contractBaseAssetBalance = baseAsset.balanceOf(address(Paytr_Test));

        emit InterestPayoutEvent(
            baseAssetAddress, 
            Paytr_Test.getMapping(paymentReference1).payee,
            interestAmount,
            paymentReference1
        );        
        
        //baseAsset balances
        assertEq(getAlicesBaseAssetBalance(), expectedAlicesBaseAssetBalance); //alice receives interest after the payOutERC20Invoice has been called
        assertEq(getBobsBaseAssetBalance(), 50_000_000e6 + amountToPay); //Bob's starting balance is 10000e6, and he is the payee of the invoice getting paid out
        assertEq(getCharliesBaseAssetBalance(), 50_000_000e6);
        assertGt(baseAsset.balanceOf(address(Paytr_Test)), 0); //the contract receives 10% of the interest amount as fee (param 9000 in setUp)
        assertEq(getDummyFeeBaseAssetBalance(), 0);
        assertApproxEqAbs(contractBaseAssetBalance, (interestAmount + contractBaseAssetBalance) * 1000 / 10000, 1); ////value of 1 because of rounding differences from Comet or CometWrapper

        //comet (cbaseAssetv3) balances
        assertEq(comet.balanceOf(alice), 0, "Alice's comet balance != 0");
        assertEq(comet.balanceOf(bob), 0, "Bob's comet balance != 0");
        assertEq(comet.balanceOf(charlie), 0, "Charlie's comet balance != 0");
        assertEq(comet.balanceOf(address(Paytr_Test)), 0,  "Contract comet balance != 0");

        //cometWrapper (wcbaseAssetv3) balances
        assertEq(getContractCometWrapperBalance(), 0);

    }

    function test_payFiveReferencesAndPayOutNoFee() public {
        vm.startPrank(alice);
        Paytr_Test.payInvoiceERC20(
            bob,
            dummyFeeAddress,
            uint40(block.timestamp + 10 days),
            amountToPay,
            0,
            paymentReference1,
            false
        );

        Paytr_Test.payInvoiceERC20(
            bob,
            dummyFeeAddress,
            uint40(block.timestamp + 10 days),
            amountToPay,
            0,
            paymentReference2,
            false
        );

        Paytr_Test.payInvoiceERC20(
            bob,
            dummyFeeAddress,
            uint40(block.timestamp + 10 days),
            amountToPay,
            0,
            paymentReference3,
            false
        );

        Paytr_Test.payInvoiceERC20(
            bob,
            dummyFeeAddress,
            uint40(block.timestamp + 10 days),
            amountToPay,
            0,
            paymentReference4,
            false
        );

        Paytr_Test.payInvoiceERC20(
            bob,
            dummyFeeAddress,
            uint40(block.timestamp + 10 days),
            amountToPay,
            0,
            paymentReference5,
            false
        );
        vm.stopPrank();

        vm.warp(block.timestamp + 30 days);

        payOutArray = [paymentReference1, paymentReference2, paymentReference3, paymentReference4, paymentReference5];
        Paytr_Test.payOutERC20Invoice(payOutArray);
    }

    function test_payTenReferencesAndPayOutNoFee() public {
        vm.startPrank(alice);
        Paytr_Test.payInvoiceERC20(
            bob,
            dummyFeeAddress,
            uint40(block.timestamp + 10 days),
            amountToPay,
            0,
            paymentReference1,
            false
        );

        Paytr_Test.payInvoiceERC20(
            bob,
            dummyFeeAddress,
            uint40(block.timestamp + 10 days),
            amountToPay,
            0,
            paymentReference2,
            false
        );

        Paytr_Test.payInvoiceERC20(
            bob,
            dummyFeeAddress,
            uint40(block.timestamp + 10 days),
            amountToPay,
            0,
            paymentReference3,
            false
        );

        Paytr_Test.payInvoiceERC20(
            bob,
            dummyFeeAddress,
            uint40(block.timestamp + 10 days),
            amountToPay,
            0,
            paymentReference4,
            false
        );

        Paytr_Test.payInvoiceERC20(
            bob,
            dummyFeeAddress,
            uint40(block.timestamp + 10 days),
            amountToPay,
            0,
            paymentReference5,
            false
        );

        Paytr_Test.payInvoiceERC20(
            bob,
            dummyFeeAddress,
            uint40(block.timestamp + 10 days),
            amountToPay,
            0,
            paymentReference6,
            false
        );

        Paytr_Test.payInvoiceERC20(
            bob,
            dummyFeeAddress,
            uint40(block.timestamp + 10 days),
            amountToPay,
            0,
            paymentReference7,
            false
        );

        Paytr_Test.payInvoiceERC20(
            bob,
            dummyFeeAddress,
            uint40(block.timestamp + 10 days),
            amountToPay,
            0,
            paymentReference8,
            false
        );

        Paytr_Test.payInvoiceERC20(
            bob,
            dummyFeeAddress,
            uint40(block.timestamp + 10 days),
            amountToPay,
            0,
            paymentReference9,
            false
        );

        Paytr_Test.payInvoiceERC20(
            bob,
            dummyFeeAddress,
            uint40(block.timestamp + 10 days),
            amountToPay,
            0,
            paymentReference10,
            false
        );
        vm.stopPrank();

        vm.warp(block.timestamp + 30 days);

        payOutArray = [paymentReference1, paymentReference2, paymentReference3, paymentReference4, paymentReference5, paymentReference6, paymentReference7, paymentReference8, paymentReference9, paymentReference10];
        Paytr_Test.payOutERC20Invoice(payOutArray);
    }

    function test_payAndRedeemSingleWithFee() public {
        assert(baseAsset.allowance(alice, address(Paytr_Test)) > 1000e6);
        vm.expectEmit(address(Paytr_Test));        

        emit PaymentERC20Event(baseAssetAddress, bob, dummyFeeAddress, amountToPay, uint40(block.timestamp + 10 days), 10000, paymentReference1);

        vm.prank(alice);
        Paytr_Test.payInvoiceERC20(
            bob,
            dummyFeeAddress,
            uint40(block.timestamp + 10 days),
            amountToPay,
            10000,
            paymentReference1,
            false
        );

        uint256 aliceBAseAssetBalanceBeforePayOut = getAlicesBaseAssetBalance();
        payOutArray = [paymentReference1];
        
        //increase time to gain interest
        vm.warp(block.timestamp + 20 days);

        vm.expectEmit(address(Paytr_Test));        

        emit PayOutERC20Event(
            baseAssetAddress,
            Paytr_Test.getMapping(paymentReference1).payee,
            Paytr_Test.getMapping(paymentReference1).feeAddress,
            Paytr_Test.getMapping(paymentReference1).amount,
            paymentReference1,
            10000
        );
        
        Paytr_Test.payOutERC20Invoice(payOutArray);

        uint256 interestAmount = getAlicesBaseAssetBalance() - aliceBAseAssetBalanceBeforePayOut;
        uint256 expectedAlicesBaseAssetBalance = interestAmount + aliceBAseAssetBalanceBeforePayOut;
        uint256 contractBaseAssetBalance = baseAsset.balanceOf(address(Paytr_Test));

        emit InterestPayoutEvent(
            baseAssetAddress, 
            Paytr_Test.getMapping(paymentReference1).payee,
            interestAmount,
            paymentReference1
        );        
        
        //baseAsset balances
        assertEq(getAlicesBaseAssetBalance(), expectedAlicesBaseAssetBalance); //alice receives interest after the payOutERC20Invoice has been called
        assertEq(getBobsBaseAssetBalance(), 50_000_000e6 + amountToPay);
        assertEq(getCharliesBaseAssetBalance(), 50_000_000e6);
        assertGt(baseAsset.balanceOf(address(Paytr_Test)), 0); //the contract receives 10% of the interest amount as fee (param 9000 in setUp)
        assertApproxEqAbs(contractBaseAssetBalance, (interestAmount + contractBaseAssetBalance) * 1000 / 10000, 1); ////value of 1 because of rounding differences from Comet or CometWrapper

        //comet (cbaseAssetv3) balances
        assertEq(comet.balanceOf(alice), 0, "Alice's comet balance != 0");
        assertEq(comet.balanceOf(bob), 0, "Bob's comet balance != 0");
        assertEq(comet.balanceOf(charlie), 0, "Charlie's comet balance != 0");
        assertEq(comet.balanceOf(address(Paytr_Test)), 0,  "Contract comet balance != 0");

        //cometWrapper (wcbaseAssetv3) balances
        assertEq(getContractCometWrapperBalance(), 0);

    }

    function test_payThreePayOutTwo() public {
        assert(baseAsset.allowance(alice, address(Paytr_Test)) > 1000e6);
        assert(baseAsset.allowance(bob, address(Paytr_Test)) > 1000e6);
        assert(baseAsset.allowance(charlie, address(Paytr_Test)) > 1000e6);

        uint256 aliceBaseAssetBalanceBeforePayment = getAlicesBaseAssetBalance();
        uint256 bobBaseAssetBalanceBeforePayment = getBobsBaseAssetBalance();
        uint256 charlieBaseAssetBalanceBeforePayment = getCharliesBaseAssetBalance();

        vm.expectEmit(address(Paytr_Test));
        emit PaymentERC20Event(baseAssetAddress, bob, dummyFeeAddress, amountToPay, uint40(block.timestamp + 10 days), 0, paymentReference1); //payer alice, payee bob

        vm.startPrank(alice);
        Paytr_Test.payInvoiceERC20(
            bob,
            dummyFeeAddress,
            uint40(block.timestamp + 10 days),
            amountToPay,
            0,
            paymentReference1,
            false
        );
        vm.stopPrank();

        vm.expectEmit(address(Paytr_Test));
        emit PaymentERC20Event(baseAssetAddress, charlie, dummyFeeAddress, amountToPay, uint40(block.timestamp + 12 days), 0, paymentReference2); //payer bob, payee charlie

        vm.startPrank(bob);
        Paytr_Test.payInvoiceERC20(
            charlie,
            dummyFeeAddress,
            uint40(block.timestamp + 12 days),
            amountToPay,
            0,
            paymentReference2,
            false
        );
        vm.stopPrank();

        vm.expectEmit(address(Paytr_Test));
        emit PaymentERC20Event(baseAssetAddress, alice, dummyFeeAddress, amountToPay, uint40(block.timestamp + 40 days), 0, paymentReference3); //payer charlie, payee alice

        vm.startPrank(charlie);
        Paytr_Test.payInvoiceERC20(
            alice,
            dummyFeeAddress,
            uint40(block.timestamp + 40 days),
            amountToPay,
            0,
            paymentReference3,
            false
        );
        vm.stopPrank();

        assertEq(getAlicesBaseAssetBalance(), aliceBaseAssetBalanceBeforePayment - amountToPay, "Alice's base balance mismatch");
        assertEq(getBobsBaseAssetBalance(), bobBaseAssetBalanceBeforePayment - amountToPay, "Bobs's base balance mismatch");
        assertEq(getCharliesBaseAssetBalance(), charlieBaseAssetBalanceBeforePayment - amountToPay, "Charlie's base balance mismatch");

        uint256 aliceBaseAssetBalanceBeforePayOut = getAlicesBaseAssetBalance();
        uint256 bobBaseAssetBalanceBeforePayOut = getBobsBaseAssetBalance();
        uint256 charlieBaseAssetBalanceBeforePayOut = getCharliesBaseAssetBalance();
        uint256 contractBaseAssetBalanceBeforePayOut = baseAsset.balanceOf(address(Paytr_Test));

        vm.expectEmit(address(Paytr_Test));
        emit PayOutERC20Event(
            baseAssetAddress,
            Paytr_Test.getMapping(paymentReference1).payee,
            Paytr_Test.getMapping(paymentReference1).feeAddress,
            Paytr_Test.getMapping(paymentReference1).amount,
            paymentReference1,
            0
        );

        vm.expectEmit(address(Paytr_Test));
        emit PayOutERC20Event(
            baseAssetAddress,
            Paytr_Test.getMapping(paymentReference2).payee,
            Paytr_Test.getMapping(paymentReference2).feeAddress,
            Paytr_Test.getMapping(paymentReference2).amount,
            paymentReference2,
            0
        ); 

        //increase time to gain interest
        vm.warp(block.timestamp + 60 days);
    
        //redeem
        payOutArray = [paymentReference1, paymentReference2];
        Paytr_Test.payOutERC20Invoice(payOutArray);

        uint256 interestAlice = getAlicesBaseAssetBalance() - aliceBaseAssetBalanceBeforePayOut; //not substracting amountToPay because paymentReference3 is not in the payOutArray
        uint256 interestBob = getBobsBaseAssetBalance() - bobBaseAssetBalanceBeforePayOut - amountToPay; //substracting amountToPay because bob receives 1000e6 from paymentReference1
        uint256 interestCharlie = getCharliesBaseAssetBalance() - charlieBaseAssetBalanceBeforePayOut - amountToPay; //substracting amountToPay because charlie receives 1000e6 from paymentReference2
        uint256 contractBaseAssetBalanceAfterPayOut = baseAsset.balanceOf(address(Paytr_Test));
        uint256 grossInterest = interestAlice + interestBob + (contractBaseAssetBalanceAfterPayOut - contractBaseAssetBalanceBeforePayOut);
        uint256 contractWrapperBalanceAfterPayOut = getContractCometWrapperBalance();

        //baseAsset balances
        assertEq(getAlicesBaseAssetBalance(), aliceBaseAssetBalanceBeforePayment - amountToPay + interestAlice, "Alice's base balance mismatch"); //alice receives interest from paymentReference1 and paid 1000e6 (ref. 1)
        assertEq(getBobsBaseAssetBalance(), bobBaseAssetBalanceBeforePayment - amountToPay + amountToPay + interestBob, "Bob's base balance mismatch"); //bob receives interest from paymentReference2, paid 1000e6 (ref. 2) and received 1000e6 (ref. 1)
        assertEq(getCharliesBaseAssetBalance(), charlieBaseAssetBalanceBeforePayment - amountToPay + amountToPay, "Charlie's base balance mismatch"); //charlie does not receive interest, because paymentReference3 is not in the payOut array. He paid 1000e6 (ref. 3) and receives 1000e6 (ref. 2)
        assertEq(interestCharlie, 0, "Charlie's interest != 0");
        assertGt(baseAsset.balanceOf(address(Paytr_Test)), 0); //the contract receives 10% of the interest amount as fee (param 9000 in setUp)
        assertApproxEqAbs(contractBaseAssetBalanceAfterPayOut, grossInterest * 1000 / 10000, 2); //value of 2 because of rounding differences from Comet and/or CometWrapper

        //comet (cbaseAssetv3) balances
        assertEq(comet.balanceOf(alice), 0, "Alice's comet balance != 0");
        assertEq(comet.balanceOf(bob), 0, "Bob's comet balance != 0");
        assertEq(comet.balanceOf(charlie), 0, "Charlie's comet balance != 0");
        assertEq(comet.balanceOf(address(Paytr_Test)), 0, "Contract comet balance != 0");

        //cometWrapper (wcbaseAssetv3) balances
        assertGt(getContractCometWrapperBalance(), 0); //needs to be > 0 because paymentReference3 is not paid out
        assertEq(getContractCometWrapperBalance(), contractWrapperBalanceAfterPayOut, "Contract wrapper balance != balance affter payout");
    
    }

    function test_usePaymentReferenceTwiceAfterPayout() public {
        //this test checks whether it's possible to pay a certain reference, have it paid out and use the same reference again
        assert(baseAsset.allowance(alice, address(Paytr_Test)) > 1000e6);
        assert(baseAsset.allowance(bob, address(Paytr_Test)) > 1000e6);
        assert(baseAsset.allowance(charlie, address(Paytr_Test)) > 1000e6);

        uint256 aliceBaseAssetBalanceBeforeFirstPayment = getAlicesBaseAssetBalance();
        uint256 bobBaseAssetBalanceBeforeFirstPayment = getBobsBaseAssetBalance();
        uint256 charlieBaseAssetBalanceBeforeFirstPayment = getCharliesBaseAssetBalance();

        vm.expectEmit(address(Paytr_Test));
        emit PaymentERC20Event(baseAssetAddress, bob, dummyFeeAddress, amountToPay, uint40(block.timestamp + 20 days), 0, paymentReference1);

        vm.startPrank(alice);
        Paytr_Test.payInvoiceERC20(
            bob,
            dummyFeeAddress,
            uint40(block.timestamp + 20 days),
            amountToPay,
            0,
            paymentReference1,
            false
        );
        vm.stopPrank();

        uint256 aliceBaseAssetBalanceAfterFirstPayment = getAlicesBaseAssetBalance();
        uint256 bobBaseAssetBalanceAfterFirstPayment = getBobsBaseAssetBalance();
        uint256 charlieBaseAssetBalanceAfterFirstPayment = getCharliesBaseAssetBalance();

        assertEq(aliceBaseAssetBalanceAfterFirstPayment, aliceBaseAssetBalanceBeforeFirstPayment - amountToPay);
        assertEq(bobBaseAssetBalanceAfterFirstPayment, bobBaseAssetBalanceBeforeFirstPayment);
        assertEq(charlieBaseAssetBalanceAfterFirstPayment,charlieBaseAssetBalanceBeforeFirstPayment);

        vm.warp(block.timestamp + 20 days);

        vm.expectEmit(address(Paytr_Test));
        emit PayOutERC20Event(
            baseAssetAddress,
            Paytr_Test.getMapping(paymentReference1).payee,
            Paytr_Test.getMapping(paymentReference1).feeAddress,
            Paytr_Test.getMapping(paymentReference1).amount,
            paymentReference1,
            0
        );

        payOutArray = [paymentReference1];
        Paytr_Test.payOutERC20Invoice(payOutArray);

        uint256 aliceBaseAssetBalanceAfterPayOut = getAlicesBaseAssetBalance();
        uint256 bobBaseAssetBalanceAfterPayOut = getBobsBaseAssetBalance();
        uint256 charlieBaseAssetBalanceAfterPayOut = getCharliesBaseAssetBalance();

        assertGt(aliceBaseAssetBalanceAfterPayOut, aliceBaseAssetBalanceAfterFirstPayment);
        assertGt(bobBaseAssetBalanceAfterPayOut, bobBaseAssetBalanceAfterFirstPayment);
        assertEq(bobBaseAssetBalanceAfterPayOut, bobBaseAssetBalanceBeforeFirstPayment + amountToPay);
        assertEq(charlieBaseAssetBalanceAfterPayOut, charlieBaseAssetBalanceBeforeFirstPayment);

        vm.expectEmit(address(Paytr_Test));
        emit PaymentERC20Event(baseAssetAddress, charlie, dummyFeeAddress, amountToPay, uint40(block.timestamp + 12 days), 0, paymentReference1);

        vm.startPrank(alice);
        Paytr_Test.payInvoiceERC20(
            charlie,
            dummyFeeAddress,
            uint40(block.timestamp + 12 days),
            amountToPay,
            0,
            paymentReference1,
            false
        );
        vm.stopPrank();

        uint256 aliceBaseAssetBalanceAfterSecondPayment = getAlicesBaseAssetBalance();
        uint256 bobBaseAssetBalanceAfterSecondPayment = getBobsBaseAssetBalance();
        uint256 charlieBaseAssetBalanceAfterSecondPayment = getCharliesBaseAssetBalance();

        assertLt(aliceBaseAssetBalanceAfterSecondPayment, aliceBaseAssetBalanceAfterPayOut);
        assertEq(aliceBaseAssetBalanceAfterSecondPayment, aliceBaseAssetBalanceAfterPayOut - amountToPay);
        assertEq(bobBaseAssetBalanceAfterSecondPayment, bobBaseAssetBalanceAfterPayOut);
        assertEq(charlieBaseAssetBalanceAfterSecondPayment, charlieBaseAssetBalanceAfterPayOut);

    }

    function test_paymentThroughRequestNetwork() public {
        assert(baseAsset.allowance(alice, address(Paytr_Test)) > 1000e6);
        uint256 feeAmount = 1e6;

        vm.expectEmit(address(this));
        emit PaymentERC20Event(baseAssetAddress, bob, dummyFeeAddress, amountToPay, uint40(block.timestamp + 28 days), feeAmount, paymentReference3);

        vm.startPrank(alice);
        Paytr_Test.payInvoiceERC20(
            bob,
            dummyFeeAddress,
            uint40(block.timestamp + 28 days),
            amountToPay,
            feeAmount,
            paymentReference3,
            true
        );
        
        //baseAsset balances
        assertEq(getAlicesBaseAssetBalance(), 50_000_000e6 - amountToPay - feeAmount);
        assertEq(getBobsBaseAssetBalance(), 50_000_000e6);
        assertEq(getCharliesBaseAssetBalance(), 50_000_000e6);
        assertEq(baseAsset.balanceOf(dummyFeeAddress), 0);
        assertEq(baseAsset.balanceOf(address(Paytr_Test)), 0);

        //comet (cbaseAssetv3) balances
        assertEq(comet.balanceOf(alice), 0);
        assertEq(comet.balanceOf(bob), 0);
        assertEq(comet.balanceOf(charlie), 0);
        assertEq(comet.balanceOf(dummyFeeAddress), 0);
        assertEq(comet.balanceOf(address(Paytr_Test)), 0);       
        
        //cometWrapper (wcbaseAssetv3) balances
        assertApproxEqRel(getContractCometWrapperBalance(), amountToPay + feeAmount, 0.1e18);

        vm.warp(block.timestamp + 29 days);

        vm.expectEmit(address(0x399F5EE127ce7432E4921a61b8CF52b0af52cbfE));

        emit TransferWithReferenceAndFee(
            baseAssetAddress,
            Paytr_Test.getMapping(paymentReference3).payee,
            Paytr_Test.getMapping(paymentReference3).amount,
            paymentReference3,
            Paytr_Test.getMapping(paymentReference3).feeAmount,
            Paytr_Test.getMapping(paymentReference3).feeAddress
        );
        
        vm.expectEmit(address(this));

        emit PayOutERC20Event(
            baseAssetAddress,
            Paytr_Test.getMapping(paymentReference3).payee,
            Paytr_Test.getMapping(paymentReference3).feeAddress,
            Paytr_Test.getMapping(paymentReference3).amount,
            paymentReference3,
            Paytr_Test.getMapping(paymentReference3).feeAmount
        );

        payOutArray = [paymentReference3];
        Paytr_Test.payOutERC20Invoice(payOutArray);

        vm.stopPrank();
    }

    function test_claimCometRewards() public {
        uint256 compBalanceBeforeClaiming = compToken.balanceOf(owner);
        console2.log("Comp balance before claiming",compBalanceBeforeClaiming);

        vm.expectEmit();
        emit PaymentERC20Event(baseAssetAddress, bob, dummyFeeAddress, amountToPay, uint40(block.timestamp + 28 days), 0, paymentReference3);

        vm.prank(alice);
        Paytr_Test.payInvoiceERC20(
            bob,
            dummyFeeAddress,
            uint40(block.timestamp + 28 days),
            amountToPay,
            0,
            paymentReference3,
            false
        );

        vm.warp(block.timestamp + 30 days);

        vm.prank(owner);
        Paytr_Test.claimCompRewards();

        //COMP balance owner
        uint256 compBalanceAfterClaiming = compToken.balanceOf(owner);
        console2.log("$COMP balance after claiming",compBalanceAfterClaiming);
        assertGt(compBalanceAfterClaiming, compBalanceBeforeClaiming);
    }

    function test_sendBaseAssetBalance() public {
        uint256 contractBaseAssetBalanceBeforePayOut = getContractBaseAssetBalance();

        test_payThreePayOutTwo();

        vm.prank(owner);
        Paytr_Test.claimBaseAssetBalance();

        assertGe(baseAsset.balanceOf(owner), 0);
        assertLe(getContractBaseAssetBalance(), contractBaseAssetBalanceBeforePayOut); //feeModifier can be 10000 (no fee applied), so contract base asset balance won't change
    }

    function test_setContractParameters() public {
        vm.expectEmit(address(Paytr_Test));
        emit ContractParametersUpdatedEvent(6000, 18 days, 365 days, 100e6, 25);

        vm.prank(owner);
        Paytr_Test.setContractParameters(6000, 18 days, 365 days, 100e6, 25);

    }

    function test_setERC20FeeProxy() public {
        vm.expectEmit(address(Paytr_Test));
        emit SetERC20FeeProxyEvent(address(0x399F5EE127ce7432E4921a61b8CF52b0af52cbfE));

        vm.prank(owner);
        Paytr_Test.setERC20FeeProxy(address(0x399F5EE127ce7432E4921a61b8CF52b0af52cbfE));

    }

    function test_getERC20FeeProxy() public {
        address feeProxyAddress = Paytr_Test.getERC20FeeProxy();
        assertEq(feeProxyAddress, address(0x399F5EE127ce7432E4921a61b8CF52b0af52cbfE));
    }

    function test_pauseAndUnpause() public {
        vm.prank(owner);
        Paytr_Test.pause();
        Paytr_Test.unpause();
    }

}
```
