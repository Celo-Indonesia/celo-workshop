"use client";

import { useWriteContract, useWaitForTransactionReceipt } from "wagmi";
import { jointVenturesConfig, CONTRACTS } from "@/lib/contracts";
import { parseUnits, erc20Abi } from "viem";

export function useRegister() {
  const { writeContract, data: hash, isPending, error } = useWriteContract();
  const { isLoading: isConfirming, isSuccess } = useWaitForTransactionReceipt({ hash });

  function register(name: string) {
    writeContract({
      ...jointVenturesConfig,
      functionName: "register",
      args: [name],
    });
  }

  return { register, isPending, isConfirming, isSuccess, error };
}

export function useApprove(tokenAddress: `0x${string}`) {
  const { writeContract, data: hash, isPending, error } = useWriteContract();
  const { isLoading: isConfirming, isSuccess } = useWaitForTransactionReceipt({ hash });

  function approve(amount: string, decimals: number) {
    writeContract({
      address: tokenAddress,
      abi: erc20Abi,
      functionName: "approve",
      args: [CONTRACTS.JOINT_VENTURES, parseUnits(amount, decimals)],
    });
  }

  return { approve, isPending, isConfirming, isSuccess, error };
}

export function useDeposit() {
  const { writeContract, data: hash, isPending, error } = useWriteContract();
  const { isLoading: isConfirming, isSuccess } = useWaitForTransactionReceipt({ hash });

  function deposit(tokenAddress: `0x${string}`, amount: string, decimals: number) {
    writeContract({
      ...jointVenturesConfig,
      functionName: "deposit",
      args: [tokenAddress, parseUnits(amount, decimals)],
    });
  }

  return { deposit, isPending, isConfirming, isSuccess, error };
}
