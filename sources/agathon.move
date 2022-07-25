// TODO: Use native coins (via generics)
// TODO: Implement withdrawals with shares
// TODO: Checks

module agathon::amm {
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

    public entry fun faucet_token1(amount: u64, recipient: address, ctx: &mut TxContext) {
        let token = Token1 {
            id: tx_context::new_id(ctx),
            value: amount,
        };
        transfer::transfer(token, recipient);
    }

    public entry fun faucet_token2(amount: u64, recipient: address, ctx: &mut TxContext) {
        let token = Token2 {
            id: tx_context::new_id(ctx),
            value: amount,
        };
        transfer::transfer(token, recipient);    
    }

    public entry fun faucet(amountToken1: u64, amountToken2: u64, ctx: &mut TxContext) {
        let recipient = tx_context::sender(ctx);
        let token1 = Token1 {
            id: tx_context::new_id(ctx),
            value: amountToken1,
        };
        transfer::transfer(token1, recipient);
        let token2 = Token2 {
            id: tx_context::new_id(ctx),
            value: amountToken2,
        };
        transfer::transfer(token2, recipient);
    }

    //
    // Pool
    //

    struct Pool has key, store {
        id: VersionedID,    
        totalToken1: u64,
        totalToken2: u64,
        K: u128,
    }

    public entry fun create_pool(amountToken1: u64, amountToken2: u64, ctx: &mut TxContext) {
        let k = amountToken1 * amountToken2;
        let pool = Pool {
            id: tx_context::new_id(ctx),
            totalToken1: amountToken1,
            totalToken2: amountToken2,
            K: (k as u128),
        };
        transfer::share_object(pool);
    }

    //
    // Provider
    //

    struct Provider has key {
        id: VersionedID,
        token1Balance: u64,
        token2Balance: u64,
    }

    public entry fun create_provider(ctx: &mut TxContext) {
        let provider = Provider {
            id: tx_context::new_id(ctx),
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

    public fun get_prices(pool: &Pool) : (u64, u64) {
        let priceToken1 = computeToken1AmountGivenToken2(pool, 1000000);
        let priceToken2 = computeToken2AmountGivenToken1(pool, 1000000);
        (priceToken1, priceToken2)
    }
}