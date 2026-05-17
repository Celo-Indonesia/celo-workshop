"use client";

import { useReadContract, useReadContracts } from "wagmi";
import { jointVenturesConfig } from "@/lib/contracts";
import { formatUnits } from "viem";

export function useJVStats() {
  const { data, isLoading, refetch } = useReadContracts({
    contracts: [
      { ...jointVenturesConfig, functionName: "target" },
      { ...jointVenturesConfig, functionName: "collectedUSD" },
      { ...jointVenturesConfig, functionName: "active" },
    ],
  });

  const target = data?.[0]?.result as bigint | undefined;
  const collectedUSD = data?.[1]?.result as bigint | undefined;
  const active = data?.[2]?.result as boolean | undefined;

  const targetFormatted = target ? Number(formatUnits(target, 6)) : 0;
  const collectedFormatted = collectedUSD ? Number(formatUnits(collectedUSD, 6)) : 0;
  const progress = targetFormatted > 0 ? (collectedFormatted / targetFormatted) * 100 : 0;

  return { target: targetFormatted, collected: collectedFormatted, progress, active, isLoading, refetch };
}

export function useIsMember(address?: `0x${string}`) {
  const { data, isLoading } = useReadContract({
    ...jointVenturesConfig,
    functionName: "members",
    args: address ? [address] : undefined,
    query: { enabled: !!address },
  });

  const member = data as [string, bigint, boolean] | undefined;

  return {
    name: member?.[0] ?? "",
    amount: member?.[1] ? Number(formatUnits(member[1], 6)) : 0,
    isMember: member?.[2] ?? false,
    isLoading,
  };
}
