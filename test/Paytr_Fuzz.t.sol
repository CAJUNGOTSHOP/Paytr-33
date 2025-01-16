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

    function testFuzz_payInvoiceERC20SingleZeroFee(uint256 _amount, address _payee) public {
        _amount = bound(_amount, 100e6, 50_000_000e6);
        vm.assume(_payee != address(0) && _payee != cometWrapperAddress && _payee != baseAssetAddress);

        assert(baseAsset.allowance(alice, address(Paytr_Test)) > _amount);

        vm.expectEmit(address(Paytr_Test));        

        emit PaymentERC20Event(baseAssetAddress, _payee, dummyFeeAddress, _amount, uint40(block.timestamp + 10 days), 0, paymentReference1);

        vm.prank(alice);
        Paytr_Test.payInvoiceERC20(
            _payee,
            dummyFeeAddress,
            uint40(block.timestamp + 10 days),
            _amount,
            0,
            paymentReference1,
            false
        );
        
        //baseAsset balances
        assertEq(getAlicesBaseAssetBalance(), 50_000_000e6 - _amount);
        assertEq(getBobsBaseAssetBalance(), 50_000_000e6);
        assertEq(getCharliesBaseAssetBalance(), 50_000_000e6);
        assertEq(getContractBaseAssetBalance(), 0);

        //comet (cbaseAssetv3) balances
        assertEq(comet.balanceOf(alice), 0);
        assertEq(comet.balanceOf(_payee), 0);
        assertEq(comet.balanceOf(charlie), 0);
        assertEq(comet.balanceOf(address(Paytr_Test)), 0);       
        
        //cometWrapper (wcbaseAssetv3) balances
        assertApproxEqRel(getContractCometWrapperBalance(), _amount, 0.1e18);

    }

    function testFuzz_payInvoiceERC20SingleWithFee(uint256 _amount, uint256 _feeAmount, address _payee, address _feeAddress) public {
        _amount = bound(_amount, 100e6, 50_000_000e6 - 10e6);
        _feeAmount = bound(_feeAmount, 1e6, 10e6);
        vm.assume(_payee != address(0) && _payee != cometWrapperAddress && _payee != baseAssetAddress);
        vm.assume(_feeAddress != address(0) && _feeAddress != cometWrapperAddress && _feeAddress != baseAssetAddress);

        assertGe(baseAsset.allowance(alice, address(Paytr_Test)), _amount + _feeAmount);

        vm.expectEmit(address(Paytr_Test));        

        emit PaymentERC20Event(baseAssetAddress, _payee, _feeAddress, _amount, uint40(block.timestamp + 10 days), _feeAmount, paymentReference1);

        vm.prank(alice);
        Paytr_Test.payInvoiceERC20(
            _payee,
            _feeAddress,
            uint40(block.timestamp + 10 days),
            _amount,
            _feeAmount,
            paymentReference1,
            false
        );
        
        //baseAsset balances
        assertEq(getAlicesBaseAssetBalance(), 50_000_000e6 - _amount - _feeAmount);
        assertEq(getBobsBaseAssetBalance(), 50_000_000e6);
        assertEq(getCharliesBaseAssetBalance(), 50_000_000e6);
        assertEq(getContractBaseAssetBalance(), 0);

        //comet (cbaseAssetv3) balances
        assertEq(comet.balanceOf(alice), 0);
        assertEq(comet.balanceOf(_payee), 0);
        assertEq(comet.balanceOf(charlie), 0);
        assertEq(comet.balanceOf(address(Paytr_Test)), 0);       
        
        //cometWrapper (wcbaseAssetv3) balances
        assertApproxEqRel(getContractCometWrapperBalance(), _amount + _feeAmount, 0.1e18);

    }

    function testFuzz_payInvoiceERC20Double(uint256 _amount, uint256 _feeAmount, address _payee, address _feeAddress) public {
        _amount = bound(_amount, 100e6, 50_000_000e6 - 10e6);
        _feeAmount = bound(_feeAmount, 1e6, 10e6);
        vm.assume(_payee != address(0) && _payee != cometWrapperAddress && _payee != baseAssetAddress);
        vm.assume(_feeAddress != address(0) && _feeAddress != cometWrapperAddress && _feeAddress != baseAssetAddress);

        assertGe(baseAsset.allowance(alice, address(Paytr_Test)), _amount + _feeAmount);
        assertGe(baseAsset.allowance(bob, address(Paytr_Test)), _amount + _feeAmount);

        vm.expectEmit(address(Paytr_Test));        

        emit PaymentERC20Event(baseAssetAddress, _payee, _feeAddress, _amount, uint40(block.timestamp + 10 days), _feeAmount, paymentReference1);

        vm.startPrank(alice);
        Paytr_Test.payInvoiceERC20(
            _payee,
            _feeAddress,
            uint40(block.timestamp + 10 days),
            _amount,
            _feeAmount,
            paymentReference1,
            false
        );
        vm.stopPrank();

        //baseAsset balances
        assertEq(getAlicesBaseAssetBalance(), 50_000_000e6 - _amount - _feeAmount, "1-1");
        assertEq(getBobsBaseAssetBalance(), 50_000_000e6, "1-2");
        assertEq(getCharliesBaseAssetBalance(), 50_000_000e6, "1-3");
        assertEq(getContractBaseAssetBalance(), 0, "1-4");
        
        //comet (cbaseAssetv3) balances
        assertEq(comet.balanceOf(alice), 0, "1-5");
        assertEq(comet.balanceOf(_payee), 0, "1-6");
        assertEq(comet.balanceOf(charlie), 0, "1-7");
        assertEq(comet.balanceOf(address(Paytr_Test)), 0, "1-8");       
        
        //cometWrapper (wcbaseAssetv3) balances
        assertApproxEqRel(getContractCometWrapperBalance(), _amount + _feeAmount, 0.1e18, "1-9");

        uint256 contractCometWrapperBalanceBeforeSecondPayment = getContractCometWrapperBalance();

        vm.expectEmit(address(Paytr_Test));        

        emit PaymentERC20Event(baseAssetAddress, _payee, _feeAddress, _amount, uint40(block.timestamp + 10 days), _feeAmount, paymentReference2);

        vm.startPrank(bob);
        Paytr_Test.payInvoiceERC20(
            _payee,
            _feeAddress,
            uint40(block.timestamp + 10 days),
            _amount,
            _feeAmount,
            paymentReference2,
            false   
        );
        vm.stopPrank();

        uint256 contractCometWrapperBalanceAfterSecondPayment = getContractCometWrapperBalance();

        //baseAsset balances
        assertEq(getBobsBaseAssetBalance(), 50_000_000e6 - _amount - _feeAmount, "1");
        assertEq(getCharliesBaseAssetBalance(), 50_000_000e6, "2");
        assertEq(getContractBaseAssetBalance(), 0, "3");

        //comet (cbaseAssetv3) balances
        assertEq(comet.balanceOf(alice), 0, "4");
        assertEq(comet.balanceOf(bob), 0, "5");
        assertEq(comet.balanceOf(_feeAddress), 0, "6");
        assertEq(comet.balanceOf(address(Paytr_Test)), 0, "7");          
        
        //cometWrapper (wcbaseAssetv3) balances
        assertApproxEqRel(contractCometWrapperBalanceAfterSecondPayment, contractCometWrapperBalanceBeforeSecondPayment + _amount + _feeAmount, 0.1e18, "8");

    }

    function testFuzz_payAndRedeemSingleZeroFee(uint256 _amount, address _payee) public {
        _amount = bound(_amount, 100e6, 50_000_000e6);
        vm.assume(_payee != address(0) && _payee != alice && _payee != bob && _payee != charlie && _payee != baseAssetAddress && _payee != cometWrapperAddress); //_payee cannot be alice, bob or charlie because they are dealt the max. amount of USDC. This can cause addition overflow in the payout
        assert(baseAsset.allowance(alice, address(Paytr_Test)) >= _amount);
        
        vm.expectEmit(address(Paytr_Test));        

        emit PaymentERC20Event(baseAssetAddress, _payee, dummyFeeAddress, _amount, uint40(block.timestamp + 10 days), 0, paymentReference1);

        vm.prank(alice);
        Paytr_Test.payInvoiceERC20(
            _payee,
            dummyFeeAddress,
            uint40(block.timestamp + 10 days),
            _amount,
            0,
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
            0
        );
        
        Paytr_Test.payOutERC20Invoice(payOutArray);

        uint256 interestAmount = getAlicesBaseAssetBalance() - aliceBAseAssetBalanceBeforePayOut;
        uint256 contractBaseAssetBalance = getContractBaseAssetBalance();

        emit InterestPayoutEvent(
            baseAssetAddress, 
            Paytr_Test.getMapping(paymentReference1).payee,
            interestAmount,
            paymentReference1
        );   
        
        //baseAsset balances
        assertGt(getContractBaseAssetBalance(), 0); //the contract receives 10% of the interest amount as fee (param 9000 in setUp)
        assertApproxEqAbs(contractBaseAssetBalance, (interestAmount + contractBaseAssetBalance) * 1000 / 10000, 1); ////value of 1 because of rounding differences from Comet or CometWrapper

        //comet (cbaseAssetv3) balances
        assertEq(comet.balanceOf(alice), 0, "Alice's comet balance != 0");
        assertEq(comet.balanceOf(bob), 0, "Bob's comet balance != 0");
        assertEq(comet.balanceOf(charlie), 0, "Charlie's comet balance != 0");
        assertEq(comet.balanceOf(address(Paytr_Test)), 0,  "Contract comet balance != 0");

        //cometWrapper (wcbaseAssetv3) balances
        assertEq(getContractCometWrapperBalance(), 0);

    }

    function testFuzz_payAndRedeemSingleWithFee(uint256 _amount, uint256 _feeAmount, address _payee, address _feeAddress) public {
        _amount = bound(_amount, 100e6, 300_000e6 - 10e6);
        _feeAmount = bound(_feeAmount, 1e6, 10e6);
        vm.assume(_payee != address(0) && _payee != alice && _payee != bob && _payee != charlie && _payee != baseAssetAddress && _payee != cometWrapperAddress); //_payee cannot be alice, bob or charlie because they are dealt the max. amount of USDC. This can cause addition overflow in the payout
        vm.assume(_feeAddress != address(0) && _feeAddress != alice && _feeAddress != bob && _feeAddress != charlie && _feeAddress != baseAssetAddress && _feeAddress != cometWrapperAddress);
        
        assert(baseAsset.allowance(alice, address(Paytr_Test)) >= _amount + _feeAmount);

        uint256 aliceBaseAssetBalanceBeforePayment = getAlicesBaseAssetBalance();
        
        vm.expectEmit(address(Paytr_Test));        

        emit PaymentERC20Event(baseAssetAddress, _payee, _feeAddress, _amount, uint40(block.timestamp + 10 days), _feeAmount, paymentReference1);

        vm.prank(alice);
        Paytr_Test.payInvoiceERC20(
            _payee,
            _feeAddress,
            uint40(block.timestamp + 10 days),
            _amount,
            _feeAmount,
            paymentReference1,
            false
        );

        uint256 aliceBaseAssetBalanceBeforePayOut = getAlicesBaseAssetBalance();
        uint256 contractBaseAssetBalanceBeforePayOut = getContractBaseAssetBalance();

        assertEq(aliceBaseAssetBalanceBeforePayOut, aliceBaseAssetBalanceBeforePayment - _amount - _feeAmount);

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
            Paytr_Test.getMapping(paymentReference1).feeAmount
        );
        
        Paytr_Test.payOutERC20Invoice(payOutArray);

        uint256 interestAmount = getAlicesBaseAssetBalance() - aliceBaseAssetBalanceBeforePayOut;

        //uint256 interestAlice = getAlicesBaseAssetBalance() - aliceBaseAssetBalanceBeforePayOut;
        uint256 contractBaseAssetBalanceAfterPayOut = getContractBaseAssetBalance();
        uint256 grossInterest = interestAmount + (contractBaseAssetBalanceAfterPayOut - contractBaseAssetBalanceBeforePayOut);
        console2.log("Gross interest: ",grossInterest);
        uint256 contractCalculatedInterest = grossInterest * 1000 / 10000;
        console2.log("contract calculated interest",contractCalculatedInterest);

        emit InterestPayoutEvent(
            baseAssetAddress, 
            Paytr_Test.getMapping(paymentReference1).payee,
            interestAmount,
            paymentReference1
        );   
        
        //baseAsset balances
        assertGt(getContractBaseAssetBalance(), contractBaseAssetBalanceBeforePayOut, "contract USDC balance mismatch"); //the contract receives 10% of the interest amount as fee (param 9000 in setUp)
        assertApproxEqAbs(contractBaseAssetBalanceAfterPayOut, grossInterest * 1000 / 10000, 5); //value of 5 because of rounding differences from Comet and/or CometWrapper
        assertEq(getContractBaseAssetBalance(), contractBaseAssetBalanceAfterPayOut);

        //comet (cbaseAssetv3) balances
        assertEq(comet.balanceOf(alice), 0, "Alice's comet balance != 0");
        assertEq(comet.balanceOf(bob), 0, "Bob's comet balance != 0");
        assertEq(comet.balanceOf(charlie), 0, "Charlie's comet balance != 0");
        assertEq(comet.balanceOf(address(Paytr_Test)), 0,  "Contract comet balance != 0");

        //cometWrapper (wcbaseAssetv3) balances
        assertEq(getContractCometWrapperBalance(), 0);

    }

    function testFuzz_payThreePayOutTwoZeroFee(uint256 _amount, address _payee) public {
        _amount = bound(_amount, 100e6, 50_000_000e6);
        vm.assume(_payee != address(0) && _payee != alice && _payee != bob && _payee != charlie && _payee != baseAssetAddress && _payee != cometWrapperAddress); //_payee cannot be alice, bob or charlie because they are dealt the max. amount of USDC. This can cause addition overflow in the payout
        assert(baseAsset.allowance(alice, address(Paytr_Test)) >= _amount);
        assert(baseAsset.allowance(bob, address(Paytr_Test)) >= _amount);

        uint256 aliceBaseAssetBalanceBeforePayment = getAlicesBaseAssetBalance();
        uint256 bobBaseAssetBalanceBeforePayment = getBobsBaseAssetBalance();
        uint256 charlieBaseAssetBalanceBeforePayment = getCharliesBaseAssetBalance();

        vm.expectEmit(address(Paytr_Test));
        emit PaymentERC20Event(baseAssetAddress, _payee, dummyFeeAddress, _amount, uint40(block.timestamp + 10 days), 0, paymentReference1);

        vm.startPrank(alice);
        Paytr_Test.payInvoiceERC20(
            _payee,
            dummyFeeAddress,
            uint40(block.timestamp + 10 days),
            _amount,
            0,
            paymentReference1,
            false
        );
        vm.stopPrank();

        vm.expectEmit(address(Paytr_Test));
        emit PaymentERC20Event(baseAssetAddress, _payee, dummyFeeAddress, _amount, uint40(block.timestamp + 12 days), 0, paymentReference2);

        vm.startPrank(bob);
        Paytr_Test.payInvoiceERC20(
            _payee,
            dummyFeeAddress,
            uint40(block.timestamp + 12 days),
            _amount,
            0,
            paymentReference2,
            false
        );
        vm.stopPrank();

        vm.expectEmit(address(Paytr_Test));
        emit PaymentERC20Event(baseAssetAddress, _payee, dummyFeeAddress, _amount, uint40(block.timestamp + 40 days), 0, paymentReference3);

        vm.startPrank(charlie);
        Paytr_Test.payInvoiceERC20(
            _payee,
            dummyFeeAddress,
            uint40(block.timestamp +40 days),
            _amount,
            0,
            paymentReference3,
            false
        );
        vm.stopPrank();

        assertEq(getAlicesBaseAssetBalance(), aliceBaseAssetBalanceBeforePayment - _amount, "Alice's base balance mismatch");
        assertEq(getBobsBaseAssetBalance(), bobBaseAssetBalanceBeforePayment - _amount, "Bobs's base balance mismatch");
        assertEq(getCharliesBaseAssetBalance(), charlieBaseAssetBalanceBeforePayment - _amount, "Charlie's base balance mismatch");

        uint256 aliceBaseAssetBalanceBeforePayOut = getAlicesBaseAssetBalance();
        uint256 bobBaseAssetBalanceBeforePayOut = getBobsBaseAssetBalance();
        uint256 charlieBaseAssetBalanceBeforePayOut = getCharliesBaseAssetBalance();
        uint256 contractBaseAssetBalanceBeforePayOut = getContractBaseAssetBalance();

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
        uint256 interestBob = getBobsBaseAssetBalance() - bobBaseAssetBalanceBeforePayOut;
        uint256 interestCharlie = getCharliesBaseAssetBalance() - charlieBaseAssetBalanceBeforePayOut;
        uint256 contractBaseAssetBalanceAfterPayOut = getContractBaseAssetBalance();
        uint256 grossInterest = interestAlice + interestBob + (contractBaseAssetBalanceAfterPayOut - contractBaseAssetBalanceBeforePayOut);
        uint256 contractWrapperBalanceAfterPayOut = getContractCometWrapperBalance();

        //baseAsset balances
        assertEq(getAlicesBaseAssetBalance(), aliceBaseAssetBalanceBeforePayment - _amount + interestAlice, "Alice's baseAsset balance mismatch"); //alice receives interest from paymentReference1 and paid ref. 1
        assertEq(getBobsBaseAssetBalance(), bobBaseAssetBalanceBeforePayment - _amount + interestBob, "Bob's base balance mismatch"); //bob receives interest from paymentReference2 and paid ref. 2
        assertEq(getCharliesBaseAssetBalance(), charlieBaseAssetBalanceBeforePayment - _amount, "Charlie's base balance mismatch"); //charlie does not receive interest, because paymentReference3 is not in the payOut array. He paid ref. 3
        assertEq(interestCharlie, 0, "Charlie's interest != 0");
        assertGt(getContractBaseAssetBalance(), 0); //the contract receives 10% of the interest amount as fee (param 9000 in setUp)
        assertApproxEqAbs(contractBaseAssetBalanceAfterPayOut, grossInterest * 1000 / 10000, 2); //value of 2 because of rounding differences from Comet and/or CometWrapper

        //comet (cbaseAssetv3) balances
        assertEq(comet.balanceOf(alice), 0, "Alice's comet balance != 0");
        assertEq(comet.balanceOf(bob), 0, "Bob's comet balance != 0");
        assertEq(comet.balanceOf(charlie), 0, "Charlie's comet balance != 0");
        assertEq(comet.balanceOf(address(Paytr_Test)), 0, "Contract comet balance != 0");

        //cometWrapper (wcbaseAssetv3) balances
        assertGt(getContractCometWrapperBalance(), 0); //needs to be > 0 because paymentReference3 is not paid out
        assertEq(getContractCometWrapperBalance(), contractWrapperBalanceAfterPayOut, "Contract wrapper balance != wrapper balance after payout");
    
    }

    function testFuzz_usePaymentReferenceTwiceAfterPayout(uint256 _amount, address _payee, address _payee2) public {
        //this test checks whether it's possible to pay a certain reference, have it paid out and use the same reference again
        vm.assume(_amount >= 100e6 && _amount <= 10_000e6); //prevent overflow if one of the payees has a high amount of baseAsset
        vm.assume(_payee != address(0) && _payee != alice && _payee != bob && _payee != charlie && _payee != baseAssetAddress && _payee != cometWrapperAddress); //_payee cannot be alice, bob or charlie because they are dealt the max. amount of USDC. This can cause addition overflow in the payout
        vm.assume(_payee2 != address(0) && _payee2 != alice && _payee2 != bob && _payee2 != charlie && _payee2 != baseAssetAddress && _payee2 != cometWrapperAddress);
        vm.assume(_payee != _payee2);
        assert(baseAsset.allowance(alice, address(Paytr_Test)) > _amount);

        vm.expectEmit(address(Paytr_Test));
        emit PaymentERC20Event(baseAssetAddress, _payee, dummyFeeAddress, _amount, uint40(block.timestamp + 25 days), 0, paymentReference1);

        vm.prank(alice);
        Paytr_Test.payInvoiceERC20(
            _payee,
            dummyFeeAddress,
            uint40(block.timestamp + 25 days),
            _amount,
            0,
            paymentReference1,
            false
        );

        vm.warp(block.timestamp + 25 days);

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

        vm.warp(block.timestamp + 5 days);

        vm.expectEmit(address(Paytr_Test));
        emit PaymentERC20Event(baseAssetAddress, _payee2, dummyFeeAddress, 10e6, uint40(block.timestamp + 10 days), 0, paymentReference1);

        vm.prank(alice);
        Paytr_Test.payInvoiceERC20(
            _payee2,
            dummyFeeAddress,
            uint40(block.timestamp + 10 days),
            10e6,
            0,
            paymentReference1,
            false
        );

    }

    function testFuzz_paymentThroughRequestNetwork(uint256 _amount, uint256 _feeAmount, address _payee, address _feeAddress) public {
        vm.assume(_feeAmount < 10e6);
        _amount = bound(_amount, 1e6, 10_000e6);
        console2.log(Paytr_Test.minTotalAmountParameter());
        vm.assume((_amount + _feeAmount) >= Paytr_Test.minTotalAmountParameter());
        vm.assume(_payee != address(0) && _payee != alice && _payee != bob && _payee != charlie && _payee != baseAssetAddress && _payee != cometWrapperAddress); //_payee cannot be alice, bob or charlie because they are dealt the max. amount of USDC. This can cause addition overflow in the payout
        vm.assume(_feeAddress != address(0) && _feeAddress != alice && _feeAddress != bob && _feeAddress != charlie&& _feeAddress != baseAssetAddress && _feeAddress != cometWrapperAddress);

        assert(baseAsset.allowance(alice, address(Paytr_Test)) > 1000e6);

        vm.expectEmit();
        emit PaymentERC20Event(baseAssetAddress, _payee, _feeAddress, _amount, uint40(block.timestamp + 28 days), _feeAmount, paymentReference3);

        vm.startPrank(alice);
        Paytr_Test.payInvoiceERC20(
            _payee,
            _feeAddress,
            uint40(block.timestamp + 28 days),
            _amount,
            _feeAmount,
            paymentReference3,
            true
        );

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
        
        vm.expectEmit();

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

    function testFuzz_sendBaseAssetBalance(uint256 _amount, address _payee) public {
        vm.assume(_amount > 0);
        _amount = bound(_amount, 1e6, 100_000e6);
        vm.assume(_payee != alice && _payee != bob && _payee != charlie && _payee != baseAssetAddress && _payee != cometWrapperAddress);
        uint256 contractBaseAssetBalanceBeforePayOut = getContractBaseAssetBalance();

        testFuzz_payAndRedeemSingleZeroFee(_amount, _payee);

        vm.prank(owner);
        Paytr_Test.claimBaseAssetBalance();

        assertGe(baseAsset.balanceOf(owner), 0);
        assertLe(getContractBaseAssetBalance(), contractBaseAssetBalanceBeforePayOut); //feeModifier can be 10000 (no fee applied), so contract base asset balance won't change
    }

}