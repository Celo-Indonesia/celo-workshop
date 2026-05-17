import { JointVenturesAbi } from "./abis/JointVenturesAbi";

export const CONTRACTS = {
  JOINT_VENTURES: "0xE981Bb5e5F9b441A373881C8FE9F6db1322aDb95" as `0x${string}`,
  TOKEN_SHARES: "0x52cf99D30e17A93cb5A0d98eF0585f30042f967b" as `0x${string}`,
  PRICE_FEED: "0x341D078d727bE58f03144F980a3682a9EAD55be7" as `0x${string}`,
  MOCK_USDC: "0x265971bcd643f3DcCB5c94111A3E3AD5542189Be" as `0x${string}`,
  MOCK_USDT: "0x1275F3565F9F28370856109f7C886F94b9816308" as `0x${string}`,
} as const;

export const WHITELISTED_TOKENS = [
  { address: CONTRACTS.MOCK_USDC, symbol: "USDC", decimals: 6 },
  { address: CONTRACTS.MOCK_USDT, symbol: "USDT", decimals: 6 },
] as const;

export const jointVenturesConfig = {
  address: CONTRACTS.JOINT_VENTURES,
  abi: JointVenturesAbi,
} as const;
