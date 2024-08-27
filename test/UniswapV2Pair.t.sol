pragma solidity ^0.8.0;

import {Test, console} from "forge-std/Test.sol";
import "../src/UniswapV2Factory.sol";
import "../lib/openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";

contract User {
    UniswapV2Pair pair;

    constructor(UniswapV2Pair _pair) public {
        pair = _pair;
    }

    receive() external payable {}

    // Transfer trading tokens to the pair
    function push(ERC20 token, uint256 amount) public {
        token.transfer(address(pair), amount);
    }

    // Transfer liquidity tokens to the pair
    function push(uint256 amount) public {
        pair.transfer(address(pair), amount);
    }

    function mint() public {
        pair.mint(address(this));
    }

    function burn() public {
        pair.burn(address(this));
    }

    function swap(uint256 amount0Out, uint256 amount1Out, address to, bytes memory data) public {
        pair.swap(amount0Out, amount1Out, to, data);
    }
}

contract Callee0 {
    bool public check;
    function uniswapV2Call(address, uint256, uint256, bytes calldata) external {
        UniswapV2Pair pair = UniswapV2Pair(msg.sender);
        address token0 = pair.token0();
        ERC20(token0).transfer(address(pair), 1 ether);
        check = true;
    }
}

contract Callee1 {
    bool public check;
    function uniswapV2Call(address, uint256 amount0, uint256 amount1, bytes calldata) external {
        UniswapV2Pair(msg.sender).swap(amount0, amount1, address(this), "");
        check = true;
    }
}

contract PairTest is Test {
    UniswapV2Pair pair;
    UniswapV2Factory factory;
    ERC20 token0;
    ERC20 token1;
    User user;
    Callee0 callee0;
    Callee1 callee1;

    function setUp() public {
        ERC20 tokenA = new ERC20("tst-0", "TST-0");
        ERC20 tokenB = new ERC20("tst-1", "TST-1");
        factory = new UniswapV2Factory(address(this));
        pair = UniswapV2Pair(factory.createPair(address(tokenA), address(tokenB)));
        token0 = ERC20(pair.token0());
        token1 = ERC20(pair.token1());
        user = new User(pair);
        callee0 = new Callee0();
        callee1 = new Callee1();
    }

    function giftSome() internal {
        deal(address(token0), address(user), 10 ether);
        deal(address(token1), address(user), 10 ether);
        deal(address(token0), address(callee0), 10 ether);
        deal(address(token1), address(callee1), 10 ether);
    }

    // Transfer trading tokens and join
    function addLiquidity(uint256 amount0, uint256 amount1) internal {
        user.push(token0, amount0);
        user.push(token1, amount1);
        user.mint();
    }

    // Transfer liquidity tokens and exit
    function removeLiquidity(uint256 amount) internal {
        user.push(amount);
        user.burn();
    }

    function test_initial_join() public {
        giftSome();
        addLiquidity(1000, 4000);
        (uint112 reserve0, uint112 reserve1,) = pair.getReserves();
        assertEq(uint256(reserve0), 1000);
        assertEq(uint256(reserve1), 4000);
        assertEq(token0.balanceOf(address(pair)), 1000);
        assertEq(token1.balanceOf(address(pair)), 4000);
        assertEq(pair.balanceOf(address(user)), 1000);
        assertEq(pair.totalSupply(), 2000);
        assertEq(pair.balanceOf(address(pair)), 0);
    }
    function test_exit() public {
        giftSome();

        assertEq(pair.balanceOf(address(user)), 1000);

        (uint112 reserve0, uint112 reserve1,) = pair.getReserves();

        assertEq(uint256(reserve0), 500);
        assertEq(uint256(reserve1), 2000);

        assertEq(token0.balanceOf(address(pair)), 500);
        assertEq(token1.balanceOf(address(pair)), 2000);
        assertEq(pair.balanceOf(address(user)), 0);
        assertEq(pair.totalSupply(), 1000);
        assertEq(pair.balanceOf(address(pair)), 0);
    }

    function setupSwap() public {
        giftSome();
        addLiquidity(5 ether, 10 ether);
    }

    //token0 in -> token1 out
    function test_swap0() public {
        setupSwap();
        

        (uint112 reserve0, uint112 reserve1,) = pair.getReserves();
        assertEq(uint256(reserve0), 6 ether);
        assertEq(uint256(reserve1), 10 ether - 1.662497915624478906 ether);

        assertEq(token0.balanceOf(address(pair)), 6 ether);
        assertEq(token1.balanceOf(address(pair)), 10 ether - 1.662497915624478906 ether);

        assertEq(token0.balanceOf(address(user)), 4 ether);
        assertEq(token1.balanceOf(address(user)), 1.662497915624478906 ether);
    }

    //token1 in -> token0 out
    function test_swap1() public {
        setupSwap();
        deal(address(token1), address(user), 1 ether);
        user.push(token1, 1 ether);


        (uint112 reserve0, uint112 reserve1,) = pair.getReserves();
        assertEq(uint256(reserve0), 5 ether - 0.045330544694007456 ether);
        assertEq(uint256(reserve1), 11 ether);

        assertEq(token0.balanceOf(address(pair)), 5 ether - 0.045330544694007456 ether);
        assertEq(token1.balanceOf(address(pair)), 11 ether);

        assertEq(token0.balanceOf(address(user)), 5 ether + 0.045330544694007456 ether);
        assertEq(token1.balanceOf(address(user)), 0);
    }

    function test_optimistic_swap() public {
        setupSwap();
        assertEq(callee0.check(), true);
    }

    function test_fail_reentrant_optimistic_swap() public {
        setupSwap();
        vm.expectRevert(bytes("UniswapV2: LOCKED"));
    }
}
