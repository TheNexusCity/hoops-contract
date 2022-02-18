const { expect } = require('chai');

describe('Hoops Contract Tests', async function()  {
    let owner, addr1, addr2;
    let Hoops,hoops;
    let price;
    it('Deployment', async function()  {
        [owner, addr1, addr2] = await ethers.getSigners();

        Hoops = await ethers.getContractFactory('Hoops');

        hoops = await Hoops.deploy(owner.address);

        await hoops.deployed(owner.address);
        
        expect(await hoops.totalSupply()).to.equal(0);

        const balance = await hoops.balanceOf(addr1.address);

        expect(balance).to.equal(0);
    });

    it('Mint hoop for own address', async function()  {
        [addr1, addr2] = await ethers.getSigners();

        Hoops = await ethers.getContractFactory('Hoops');

        hoops = await Hoops.deploy(addr2.address);

        await hoops.deployed(addr2.address);

        expect(await hoops.totalSupply()).to.equal(0);

        await hoops.balanceOf(addr1.address);

        price = await hoops.getMintPrice();
            
        await hoops["mint(uint256)"](1, {
            value: price,
          });
    });

    it('Total supply should increase', async function()  {
        expect(await hoops.totalSupply()).to.equal(1);
    });

    it('Mint hoop for treasury address', async function()  {
        const price = await hoops.getMintPrice();
        await hoops["mintForAddress(uint256,address)"](1,addr2.address,{ value: price });
        const tknBal = await hoops.balanceOf(addr2.address);
        expect(tknBal).to.equal(1);
        expect(await hoops.totalSupply()).to.equal(2);
    });

    it('Total supply should increase', async function()  {
        expect(await hoops.totalSupply()).to.equal(2);
    });

    describe('Transactions ',async () => {
        it('Should transfer from owner to other address', async function()  {
            await hoops.transferFrom(addr1.address,addr2.address,0);
            const tknBal = await hoops.balanceOf(addr1.address);
            expect(tknBal).to.equal(0);
        });

        it('Should transfer from treasury to other address', async function()  {
            await hoops.connect(addr2).transferFrom(addr2.address,addr1.address,1);
            const tknBal = await hoops.balanceOf(addr2.address);
            expect(tknBal).to.equal(1);
        });
    });

    describe('Approval ',async () => {
        it('Owner should approve other account to transfer NFT', async function()  {
            await hoops.approve(addr2.address,1);
            expect( await hoops.getApproved(1)).to.equal(addr2.address);
        });
    });

    describe('Third party ',async () => {
        it('Other address should transfer hoop', async function()  {
            await hoops.connect(addr2).transferFrom(addr1.address,addr2.address,1);
            const tknBal = await hoops.balanceOf(addr2.address);
            expect(tknBal).to.equal(2);
        });
    });

    describe('Owner set contract ',async () => {
        it('Owner should set the contract to be mintable for everybody ', async function()  {
            await hoops.connect(owner).setOpenMint(true);
            let nonWhitelistPrice = await hoops.getMintPrice();
            await hoops.connect(addr1)["mint(uint256)"](1, {
                value: nonWhitelistPrice,
              });

            const tknBal = await hoops.balanceOf(addr1.address);
            expect(tknBal).to.equal(1);
        });

        it('Total supply should increase', async function()  {
            expect(await hoops.totalSupply()).to.equal(3);
        });
    });
});