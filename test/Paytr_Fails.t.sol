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

    function testFail_zeroAmountZeroFee() public {

        uint256 amountToPay = 0;

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

    }

    function testFail_zeroAmountWithFee() public {

        uint256 amountToPay = 0;

        vm.prank(alice);
        Paytr_Test.payInvoiceERC20(
            bob,
            dummyFeeAddress,
            uint40(block.timestamp + 10 days),
            amountToPay,
            1000e6,
            paymentReference1,
            false
        );

    }

    function testFail_amountTooLow() public { //the min. amount is specified in the contract parameters.

        uint256 amountToPay = 9e6;

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
        
    }

    function testFail_zeroPayeeAddress() public {

        uint256 amountToPay = 1000e6;

        vm.prank(alice);
        Paytr_Test.payInvoiceERC20(
            address(0),
            dummyFeeAddress,
            uint40(block.timestamp + 10 days),
            amountToPay,
            0,
            paymentReference1,
            false
        );
        
    }

    function testFail_zeroFeeAddress() public {

        uint256 amountToPay = 1000e6;

        vm.prank(alice);
        Paytr_Test.payInvoiceERC20(
            bob,
            address(0),
            uint40(block.timestamp + 10 days),
            amountToPay,
            0,
            paymentReference1,
            false
        );
        
    }

    function testFail_paymentReferenceInUse() public {

        uint256 amountToPay = 1000e6;

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

        vm.prank(bob);
        Paytr_Test.payInvoiceERC20(
            charlie,
            dummyFeeAddress,
            uint40(block.timestamp + 18 days),
            amountToPay,
            0,
            paymentReference1,
            false
        );
        
    }

    function testFail_dueDateTooLow() public {

        uint256 amountToPay = 1000e6;

        vm.prank(alice);
        Paytr_Test.payInvoiceERC20(
            bob,
            dummyFeeAddress,
            uint40(block.timestamp + 1 days),
            amountToPay,
            0,
            paymentReference1,
            false
        );
        
    }

    function testFail_dueDateTooHigh() public {

        uint256 amountToPay = 1000e6;

        vm.prank(alice);
        Paytr_Test.payInvoiceERC20(
            bob,
            dummyFeeAddress,
            uint40(block.timestamp + 450 days),
            amountToPay,
            0,
            paymentReference1,
            false
        );
        
    }

    function testFail_payOutArrayTooSmall() public {
        Paytr_Test.payOutERC20Invoice(payOutArray);
    }

    function testFail_payOutArrayTooBig() public {
        payOutArray = [
            paymentReference1,
            paymentReference2,
            paymentReference3,
            paymentReference4,
            paymentReference5,
            paymentReference6,
            paymentReference7,
            paymentReference8,
            paymentReference9,
            paymentReference10,
            paymentReference11,
            paymentReference12,
            paymentReference13,
            paymentReference14,
            paymentReference15,
            paymentReference16            
        ];
        Paytr_Test.payOutERC20Invoice(payOutArray);
    }

    function testFail_noPrePayment() public {
        payOutArray = [paymentReference1]; //this reference hasn't been prepaid in this function, so it should not be able to redeem it

        Paytr_Test.payOutERC20Invoice(payOutArray);
    }

    function testFail_notDue() public {
        uint256 amountToPay = 1000e6;

        vm.prank(alice);
        Paytr_Test.payInvoiceERC20(
            bob,
            dummyFeeAddress,
            uint40(block.timestamp + 20 days),
            amountToPay,
            0,
            paymentReference1,
            false
        );

        vm.warp(block.timestamp + 15 days);

        payOutArray = [paymentReference1];

        Paytr_Test.payOutERC20Invoice(payOutArray);

    }

    function testFail_alreadyPaidOut() public {
        uint256 amountToPay = 1000e6;

        vm.prank(alice);
        Paytr_Test.payInvoiceERC20(
            bob,
            dummyFeeAddress,
            uint40(block.timestamp + 20 days),
            amountToPay,
            0,
            paymentReference1,
            false
        );

        vm.warp(block.timestamp + 21 days);
        payOutArray = [paymentReference1];
        Paytr_Test.payOutERC20Invoice(payOutArray);

        vm.warp(block.timestamp + 150 days);
        payOutArray = [paymentReference1];
        Paytr_Test.payOutERC20Invoice(payOutArray);

    }

    function testFail_updateDueDateWhenDateIsNotZero() public {
        uint256 amountToPay = 1000e6;
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

        updateDueDate(paymentReference1);
        vm.stopPrank();
    }

    function testFail_claimCompRewardsNotOwner() public {
        vm.prank(bob);
        Paytr_Test.claimCompRewards();
    }

    function testFail_changeParametersNotOwner() public {
        vm.prank(alice);
        Paytr_Test.setContractParameters(
            8000,
            20 days,
            365 days,
            100e6,
            60
        );
    }

    function testFail_changeParametersInvalidContractFeeModifier() public {
        vm.prank(owner);
        Paytr_Test.setContractParameters(
            1,
            20 days,
            365 days,
            100e6,
            60
        );
    }

    function testFail_changeParametersInvalidMinDueDate() public {
        vm.prank(owner);
        Paytr_Test.setContractParameters(
            8000,
            1 days,
            365 days,
            100e6,
            60
        );
    }

    function testFail_changeParametersInvalidMaxDueDate() public {
        vm.prank(owner);
        Paytr_Test.setContractParameters(
            8000,
            20 days,
            5000 days,
            100e6,
            60
        );
    }

    function testFail_changeParametersInvalidMinAmount() public {
        vm.prank(owner);
        Paytr_Test.setContractParameters(
            8000,
            20 days,
            365 days,
            0,
            60
        );
    }

    //Paytr.sol doesn't check the maxAmount parameter, no test needed

    function testFail_changeParametersInvalidMaxPayOutArraySize() public {
        vm.prank(owner);
        Paytr_Test.setContractParameters(
            8000,
            20 days,
            365 days,
            100e6,
            0
        );
    }

    function testFail_dueDateTooLowEscrow() public {
        uint256 amountToPay = 1000e6;

        vm.prank(alice);
        Paytr_Test.payInvoiceERC20Escrow(
            bob,
            dummyFeeAddress,
            amountToPay,
            0,
            paymentReference1,
            false
        );
    }

    function testFail_dueDateTooHighEscrow() public {
        uint256 amountToPay = 1000e6;

        vm.prank(alice);
        Paytr_Test.payInvoiceERC20Escrow(
            bob,
            dummyFeeAddress,
            amountToPay,
            0,
            paymentReference1,
            false
        );
    }
}
