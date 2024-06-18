///
/// Seed normalisation
///

import {BigNumber} from "ethers";

export function normalizeSeed(rawSeed: BigNumber, tokenId: BigNumber): BigNumber {
    return rawSeed.xor(tokenId).mod(2**32-1);
}

export function seedForProbability(tokenId: BigNumber, ticketProbability: BigNumber): BigNumber {
    // seed ^ tokenId % 2**32-1 = ticketProbability
    // seed ^ tokenId = ticketProbability % 2**32-1
    // seed = ticketProbability % 2**32-1 ^ tokenId
    return ticketProbability.mod(2**32-1).xor(tokenId);
}