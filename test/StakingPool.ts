import {
  time,
  loadFixture,
  mine
} from "@nomicfoundation/hardhat-toolbox-viem/network-helpers";
import { expect } from "chai";
import hre from "hardhat";
import { getAddress, parseGwei } from "viem";

describe("StakingPool", function () {
  async function deployOneYearLockFixture() {
    const [owner, user, user2] = await hre.viem.getWalletClients();
    const stakingToken = await hre.viem.deployContract("StakingToken")
    const rewardToken = await hre.viem.deployContract("RewardToken")
    const stakingPool = await hre.viem.deployContract("StakingPool", [stakingToken.address, rewardToken.address]);

    await stakingToken.write.transfer([user.account.address, BigInt(1e18)]);
    await stakingToken.write.transfer([user2.account.address, BigInt(1e18)]);

    const publicClient = await hre.viem.getPublicClient();

    return {
      stakingPool,
      stakingToken,
      rewardToken,
      owner,
      user,
      publicClient,
    };
  }

  describe("Deployment", function () {

    it("Should have staking token set", async function () {
      const { stakingPool, stakingToken, owner, user } = await loadFixture(deployOneYearLockFixture);
      const stakingTokenAddress = getAddress(stakingToken.address);
      expect(await stakingPool.read.stakingToken()).to.equal(stakingTokenAddress);
    });

    it("Should have reward token set", async function () {
      const { stakingPool, rewardToken } = await loadFixture(deployOneYearLockFixture);
      const rewardTokenAddress = getAddress(rewardToken.address);
      expect(await stakingPool.read.rewardToken()).to.equal(rewardTokenAddress);
    })
  });

  describe("Staking", async function () {

    it("Should update variables correctly on staking", async function () {
      const { stakingPool, stakingToken, publicClient, user } = await loadFixture(deployOneYearLockFixture);

      const amount = BigInt(100);

      await stakingToken.write.approve([stakingPool.address, amount], { account: user.account.address });

      const hash = await stakingPool.write.stake([amount], { account: user.account.address })
      await publicClient.waitForTransactionReceipt({ hash });

      expect(await stakingPool.read.totalStakedSupply()).to.equal(amount);
      expect(await stakingPool.read.stakedBalance([user.account.address])).to.equal(amount);
      expect(await stakingToken.read.balanceOf([stakingPool.address])).to.equal(amount);
    });

    it("Should update variables correctly on withdrawing", async function () {
      const { stakingPool, stakingToken, publicClient, user } = await loadFixture(deployOneYearLockFixture);

      const amount = BigInt(100);

      await stakingToken.write.approve([stakingPool.address, amount], { account: user.account.address });

      const hash = await stakingPool.write.stake([amount], { account: user.account.address })
      await publicClient.waitForTransactionReceipt({ hash });

      const withdrawAmount = BigInt(50);

      const withdrawHash = await stakingPool.write.withdraw([withdrawAmount], { account: user.account.address });
      await publicClient.waitForTransactionReceipt({ hash: withdrawHash });

      expect(await stakingPool.read.totalStakedSupply()).to.equal(amount - withdrawAmount);
      expect(await stakingPool.read.stakedBalance([user.account.address])).to.equal(amount - withdrawAmount);
      expect(await stakingToken.read.balanceOf([stakingPool.address])).to.equal(amount - withdrawAmount);
    });

    it("Should update rewards correctly", async function () {
      const { stakingPool, stakingToken, publicClient, user } = await loadFixture(deployOneYearLockFixture);

      const amount = BigInt(100);

      await stakingToken.write.approve([stakingPool.address, amount], { account: user.account.address });

      const hash = await stakingPool.write.stake([amount], { account: user.account.address })
      await publicClient.waitForTransactionReceipt({ hash });

      mine(100);

      expect(await stakingPool.read.earned([user.account.address])).to.equal(100 * 100);
    });
  });
});