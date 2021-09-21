// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// When running the script with `npx hardhat run <script>` you'll find the Hardhat
// Runtime Environment's members available in the global scope.

const hre = require("hardhat");

async function main() {
  let MockContract, MarketPlace, owner, signer1, provider;
  // Hardhat always runs the compile task when running scripts with its command
  // line interface.
  //
  // If this script is run directly using `node` you may want to call compile
  // manually to make sure everything is compiled
  // await hre.run('compile');
  [owner, signer1] = await ethers.getSigners();
  // We get the contract to deploy
  MockContract = await hre.ethers.getContractFactory("TIM");
  MarketPlace = await hre.ethers.getContractFactory("MarketPlace");
  MockContract = await MockContract.deploy("sample ipfs url");
  await MockContract.deployed();
  MarketPlace = await MarketPlace.deploy(
    "0x737554B2685FA84898c4F166b9F3e88E22Ef5435"
  );
  provider = ethers.provider;
  await MarketPlace.deployed();
  console.log("Mock ERC1155 deployed to:", MockContract.address);
  console.log("marketPlace  deployed to:", MarketPlace.address);
  console.log((await provider.getBalance(owner.address)).toString());
  await MockContract.setApprovalForAll(MarketPlace.address, true);
  await MarketPlace.setSaleOrder(
    MockContract.address,
    0,
    200,
    true,
    "10000000000000000000",
    0,
    12
  );
  console.log(await MarketPlace.checkOrder(0));

  await MarketPlace.connect(signer1).fulfillOrder(0, {
    value: "10000000000000000000",
  });
  console.log(await MarketPlace.checkOrder(0));
  console.log((await MockContract.balanceOf(signer1.address, 0)).toString());
  console.log((await provider.getBalance(owner.address)).toString());
  console.log((await provider.getBalance(MarketPlace.address)).toString());
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
