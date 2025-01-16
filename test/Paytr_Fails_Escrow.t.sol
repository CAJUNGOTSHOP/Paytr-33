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

    function testFail_zeroAmountZeroFeeEscrow() public {

        uint256 amountToPay = 0;

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

    function testFail_zeroAmountWithFeeEscrow() public {

        uint256 amountToPay = 0;

        vm.prank(alice);
        Paytr_Test.payInvoiceERC20Escrow(
            bob,
            dummyFeeAddress,
            amountToPay,
            1000e6,
            paymentReference1,
            false
        );

    }

    function testFail_amountTooLowEscrow() public { //the min. total amount is specified in the contract parameters.

        uint256 amountToPay = 9e6;

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

    function testFail_zeroPayeeAddressEscrow() public {

        uint256 amountToPay = 1000e6;

        vm.prank(alice);
        Paytr_Test.payInvoiceERC20Escrow(
            address(0),
            dummyFeeAddress,
            amountToPay,
            0,
            paymentReference1,
            false
        );
        
    }

    function testFail_zeroFeeAddressEscrow() public {

        uint256 amountToPay = 1000e6;

        vm.prank(alice);
        Paytr_Test.payInvoiceERC20Escrow(
            bob,
            address(0),
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

    function testFail_notDueEscrow() public {
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

        vm.warp(block.timestamp + 15 days);

        payOutArray = [paymentReference1];

        Paytr_Test.payOutERC20Invoice(payOutArray);

    }

    function testFail_alreadyPaidOutEscrow() public {
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

        updateDueDate(paymentReference1);

        vm.warp(block.timestamp + 1 days);
        payOutArray = [paymentReference1];
        Paytr_Test.payOutERC20Invoice(payOutArray);

        vm.warp(block.timestamp + 2 days);
        payOutArray = [paymentReference1];
        Paytr_Test.payOutERC20Invoice(payOutArray);

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
