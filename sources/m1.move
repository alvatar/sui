module agathon::m1 {
    use sui::id::VersionedID;
    use sui::tx_context::{Self, TxContext};
    use sui::transfer;

    //
    // Tokens
    //

    struct Token1 has key {
        id: VersionedID,
        value: u64,
    }

    struct Token2 has key {
        id: VersionedID,
        value: u64,
    }

    public entry fun mint_token1(amount: u64, recipient: address, ctx: &mut TxContext) {
        let token = Token1 {
            id: tx_context::new_id(ctx),
            value: amount,
        };
        transfer::transfer(token, recipient);
    }

    public entry fun mint_token2(amount: u64, recipient: address, ctx: &mut TxContext) {
        let token = Token2 {
            id: tx_context::new_id(ctx),
            value: amount,
        };
        transfer::transfer(token, recipient);    
    }

    //
    // Pool
    //

    struct Pool has key {
        id: VersionedID,    
        totalShares: u64,
        totalToken1: u64,
        totalToken2: u64,
        K: u128,
    }

    public entry fun create_pool(amountToken1: u64, amountToken2: u64, ctx: &mut TxContext) {
        let k = amountToken1 * amountToken2;
        let pool = Pool {
            id: tx_context::new_id(ctx),
            totalShares: 0,
            totalToken1: amountToken1,
            totalToken2: amountToken2,
            K: (k as u128),
        };
        transfer::share_object(pool);
    }

    //
    // Provider
    //
    struct Provider has key, store {
        id: VersionedID,
        shares: u64,
        token1Balance: u64,
        token2Balance: u64,
    }

    public entry fun create_provider(ctx: &mut TxContext) {
        let provider = Provider {
            id: tx_context::new_id(ctx),
            shares: 0, // TODO
            token1Balance: 0,
            token2Balance: 0,
        };

        transfer::transfer(provider, tx_context::sender(ctx));
    }

    public entry fun provide(pool: &mut Pool,
                            provider: &mut Provider,
                            token1: &mut Token1,
                            amountToken1: u64,
                            token2: &mut Token2,
                            amountToken2: u64) {
        provider.token1Balance = provider.token1Balance + amountToken1;
        provider.token2Balance = provider.token2Balance + amountToken2;

        token1.value = token1.value - amountToken1;
        token2.value = token2.value - amountToken2;

        pool.totalToken1 = pool.totalToken1 + token1.value;
        pool.totalToken2 = pool.totalToken2 + token2.value;
        pool.K = (pool.totalToken1 as u128) * (pool.totalToken2 as u128);
    }

    //
    // Swapping
    //

    public fun computeToken2AmountGivenToken1(pool: &Pool, token1Amount: u64) : u64 {
        let token1After = pool.totalToken1 + token1Amount;
        let token2After = ((pool.K / (token1After as u128)) as u64);
        let token2Amount = token2After - pool.totalToken2;
        token2Amount
    }

    public entry fun swap_given_token1(
                        pool: &mut Pool,
                        token1: &mut Token1,
                        amountToken1: u64,
                        token2: &mut Token2) {
        // TODO: check ownership of tokens
        // TODO: check enough tokens in pool
        let amountToken2 = computeToken2AmountGivenToken1(pool, amountToken1);

        token1.value = token1.value - amountToken1;
        token2.value = token2.value + amountToken2;

        pool.totalToken1 = pool.totalToken1 + amountToken1;
        pool.totalToken2 = pool.totalToken2 - amountToken2;
    }

    public fun computeToken1AmountGivenToken2(pool: &Pool, token2Amount: u64) : u64 {
        let token2After = pool.totalToken2 + token2Amount;
        let token1After = ((pool.K / (token2After as u128)) as u64);
        let token1Amount = token1After - pool.totalToken1;
        token1Amount
    }

    public entry fun swap_given_token2(
                        pool: &mut Pool,
                        token1: &mut Token1,
                        token2: &mut Token2,
                        amountToken2: u64,
                        ) {
        // TODO: check ownership of tokens
        // TODO: check enough tokens in pool
        let amountToken1 = computeToken1AmountGivenToken2(pool, amountToken2);

        token1.value = token1.value + amountToken1;
        token2.value = token2.value - amountToken2;

        pool.totalToken1 = pool.totalToken1 - amountToken1;
        pool.totalToken2 = pool.totalToken2 + amountToken2;
    }

    // module initializer to be executed when this module is published
    // fun init(ctx: &mut TxContext) {
    //     use sui::transfer;
    //     use sui::tx_context;
    //     let admin = Pool {
    //         id: tx_context::new_id(ctx),
    //         totalShares: 100,
    //         totalToken1: 100,
    //         totalToken2: 100,
    //         K: 100*100,
    //     };
    //     // transfer the forge object to the module/package publisher
    //     // (presumably the game admin)
    //     transfer::transfer(admin, tx_context::sender(ctx));
    // }

    // #[test]
    // public fun test_module_init() {
    //     use sui::test_scenario;

    //     // create test address representing game admin
    //     let admin = @0xABBA;

    //     // first transaction to emulate module initialization
    //     let scenario = &mut test_scenario::begin(&admin);
    //     {
    //         init(test_scenario::ctx(scenario));
    //     };
    //     // second transaction to check if the forge has been created
    //     // and has initial value of zero swords created
    //     test_scenario::next_tx(scenario, &admin);
    //     {
    //         // extract the Pool object
    //         let pool = test_scenario::take_owned<Pool>(scenario);
    //         // verify number of created swords
    //         //assert!(swords_created(&forge) == 0, 1);
    //         // return the AMM Pool object to the object pool
    //         test_scenario::return_owned(scenario, pool)
    //     }
    // }    

    // #[test]
    // public fun test_sword_create() {
    //     use sui::transfer;
    //     use sui::tx_context;

    //     // create a dummy TxContext for testing
    //     let ctx = tx_context::dummy();

    //     // create a sword
    //     let sword = Sword {
    //         id: tx_context::new_id(&mut ctx),
    //         magic: 42,
    //         strength: 7,
    //     };

    //     // check if accessor functions return correct values
    //     assert!(magic(&sword) == 42 && strength(&sword) == 7, 1);

    //     // create a dummy address and transfer the sword
    //     let dummy_address = @0xCAFE;
    //     transfer::transfer(sword, dummy_address);
    // }

    // #[test]
    // fun test_sword_transactions() {
    //     use sui::test_scenario;
    //     use sui::tx_context;

    //     // create test addresses representing users
    //     let admin = @0xBABE;
    //     let initial_owner = @0xCAFE;
    //     let final_owner = @0xFACE;

    //     // first transaction to emulate module initialization
    //     let scenario = &mut test_scenario::begin(&admin);
    //     {
    //         init(test_scenario::ctx(scenario));
    //     };
    //     // second transaction executed by admin to create the sword
    //     test_scenario::next_tx(scenario, &admin);
    //     {
    //         let forge = test_scenario::take_owned<Forge>(scenario);
    //         // create the sword and transfer it to the initial owner
    //         sword_create(&mut forge, 42, 7, initial_owner, test_scenario::ctx(scenario));
    //         test_scenario::return_owned(scenario, forge)
    //     };
    //     // third transaction executed by the initial sword owner
    //     test_scenario::next_tx(scenario, &initial_owner);
    //     {
    //         // extract the sword owned by the initial owner
    //         let sword = test_scenario::take_owned<Sword>(scenario);
    //         // transfer the sword to the final owner
    //         let ctx = tx_context::dummy();
    //         sword_transfer(sword, final_owner, &mut ctx);
    //     };
    //     // fourth transaction executed by the final sword owner
    //     test_scenario::next_tx(scenario, &final_owner);
    //     {

    //         // extract the sword owned by the final owner
    //         let sword = test_scenario::take_owned<Sword>(scenario);
    //         // verify that the sword has expected properties
    //         assert!(magic(&sword) == 42 && strength(&sword) == 7, 1);
    //         // return the sword to the object pool (it cannot be simply "dropped")
    //         test_scenario::return_owned(scenario, sword)
    //     }
    // }
}