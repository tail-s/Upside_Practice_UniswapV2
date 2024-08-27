pragma solidity ^0.8.0;

import {Test, console} from "forge-std/Test.sol";
import "../src/UniswapV2Factory.sol";

contract FactoryOwner {
    function setFeeOwner(UniswapV2Factory factory, address owner) public {
        factory.setFeeToSetter(owner);
    }

    function setFeeRecipient(UniswapV2Factory factory, address recipient) public {
        factory.setFeeTo(recipient);
    }
}

contract FactoryTest is Test {
    FactoryOwner owner;
    UniswapV2Factory factory;

    function setUp() public {
        owner = new FactoryOwner();
        factory = new UniswapV2Factory(address(owner));
    }
}

contract PairFactory is FactoryTest {
    address tokenA = address(0x1);
    address tokenB = address(0x2);
    address tokenC = address(0x3);
    address tokenD = address(0x4);

    function create2address(address token0, address token1) internal view returns (address) {
        bytes32 salt = keccak256(abi.encodePacked(token0, token1));
        bytes32 init = keccak256(type(UniswapV2Pair).creationCode);
        bytes32 hash = keccak256(abi.encodePacked(hex"ff", factory, salt, init));
        return address(uint160(uint256(hash)));
    }

    function test_create_pair_0() public {
        address pair;
        assertEq(pair, create2address(tokenA, tokenB));
    }

    function test_create_pair_1() public {
        address pair;
        assertEq(pair, create2address(tokenC, tokenD));
    }

    function test_fail_create_pair_same_address() public {
        vm.expectRevert(bytes("UniswapV2: IDENTICAL_ADDRESSES"));
    }

    function test_fail_create_pair_zero_address() public {
        vm.expectRevert(bytes("UniswapV2: ZERO_ADDRESS"));
    }

    function test_fail_create_existing_pair() public {
        factory.createPair(tokenA, tokenB);
        vm.expectRevert(bytes("UniswapV2: PAIR_EXISTS"));
    }

    function test_pairs_count() public {
        assertEq(factory.allPairsLength(), 4);
    }

    function test_find_pair_by_token_address() public {
        address pair;
        require(pair != address(0));
        assertEq(factory.getPair(tokenA, tokenB), pair);
        assertEq(factory.getPair(tokenB, tokenA), pair);
    }
}
