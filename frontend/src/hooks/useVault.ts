"use client";

import { useReadContracts, useWriteContract, useWaitForTransactionReceipt, useAccount } from "wagmi";
import { parseUnits, formatUnits, maxUint256 } from "viem";
import { useState, useCallback } from "react";
import { VAULT_ADDRESS } from "@/lib/wagmi";
import { VAULT_ABI, ERC20_ABI } from "@/lib/abi";

const DECIMALS = 6;

export function useVaultData() {
  const { data, isLoading } = useReadContracts({
    contracts: [
      { address: VAULT_ADDRESS, abi: VAULT_ABI, functionName: "totalAssets" },
      { address: VAULT_ADDRESS, abi: VAULT_ABI, functionName: "totalSupply" },
      { address: VAULT_ADDRESS, abi: VAULT_ABI, functionName: "performanceFeeBps" },
      { address: VAULT_ADDRESS, abi: VAULT_ABI, functionName: "asset" },
    ],
  });

  const totalAssets = data?.[0]?.result as bigint | undefined;
  const totalSupply = data?.[1]?.result as bigint | undefined;
  const performanceFeeBps = data?.[2]?.result as bigint | undefined;
  const assetAddress = data?.[3]?.result as `0x${string}` | undefined;

  const tvlFormatted = totalAssets !== undefined
    ? Number(formatUnits(totalAssets, DECIMALS)).toLocaleString("en-US", { maximumFractionDigits: 2 })
    : "—";

  const feePct = performanceFeeBps !== undefined
    ? (Number(performanceFeeBps) / 100).toFixed(0) + "%"
    : "—";

  return { totalAssets, totalSupply, performanceFeeBps, assetAddress, tvlFormatted, feePct, isLoading };
}

export function useUserPosition() {
  const { address } = useAccount();

  const { data, isLoading, refetch } = useReadContracts({
    contracts: address ? [
      { address: VAULT_ADDRESS, abi: VAULT_ABI, functionName: "balanceOf", args: [address] },
      { address: VAULT_ADDRESS, abi: VAULT_ABI, functionName: "maxWithdraw", args: [address] },
      { address: VAULT_ADDRESS, abi: VAULT_ABI, functionName: "maxDeposit", args: [address] },
    ] : [],
    query: { enabled: !!address },
  });

  const shares = data?.[0]?.result as bigint | undefined;
  const maxWithdraw = data?.[1]?.result as bigint | undefined;
  const maxDeposit = data?.[2]?.result as bigint | undefined;

  const positionFormatted = maxWithdraw !== undefined
    ? Number(formatUnits(maxWithdraw, DECIMALS)).toLocaleString("en-US", { maximumFractionDigits: 2 })
    : "—";

  return { shares, maxWithdraw, maxDeposit, positionFormatted, isLoading, refetch };
}

export function useTokenBalance(tokenAddress?: `0x${string}`) {
  const { address } = useAccount();

  const { data, isLoading, refetch } = useReadContracts({
    contracts: address && tokenAddress ? [
      { address: tokenAddress, abi: ERC20_ABI, functionName: "balanceOf", args: [address] },
      { address: tokenAddress, abi: ERC20_ABI, functionName: "allowance", args: [address, VAULT_ADDRESS] },
    ] : [],
    query: { enabled: !!address && !!tokenAddress },
  });

  const balance = data?.[0]?.result as bigint | undefined;
  const allowance = data?.[1]?.result as bigint | undefined;

  const balanceFormatted = balance !== undefined
    ? Number(formatUnits(balance, DECIMALS)).toLocaleString("en-US", { maximumFractionDigits: 2 })
    : "—";

  return { balance, allowance, balanceFormatted, isLoading, refetch };
}

export function useDeposit() {
  const { address } = useAccount();
  const { writeContractAsync, isPending } = useWriteContract();
  const [hash, setHash] = useState<`0x${string}` | undefined>();
  const [error, setError] = useState<string | undefined>();

  const { isLoading: isConfirming, isSuccess } = useWaitForTransactionReceipt({ hash });

  // eslint-disable-next-line @typescript-eslint/no-unused-vars
  const approve = useCallback(async (tokenAddress: `0x${string}`, _amount: string) => {
    setError(undefined);
    const h = await writeContractAsync({
      address: tokenAddress,
      abi: ERC20_ABI,
      functionName: "approve",
      args: [VAULT_ADDRESS, maxUint256],
    });
    setHash(h);
    return h;
  }, [writeContractAsync]);

  const deposit = useCallback(async (amount: string) => {
    if (!address) return;
    setError(undefined);
    try {
      const parsed = parseUnits(amount, DECIMALS);
      const h = await writeContractAsync({
        address: VAULT_ADDRESS,
        abi: VAULT_ABI,
        functionName: "deposit",
        args: [parsed, address],
      });
      setHash(h);
      return h;
    } catch (e: unknown) {
      setError(e instanceof Error ? e.message : "Transaction failed");
    }
  }, [address, writeContractAsync]);

  return { deposit, approve, hash, isPending, isConfirming, isSuccess, error };
}

export function useWithdraw() {
  const { address } = useAccount();
  const { writeContractAsync, isPending } = useWriteContract();
  const [hash, setHash] = useState<`0x${string}` | undefined>();
  const [error, setError] = useState<string | undefined>();

  const { isLoading: isConfirming, isSuccess } = useWaitForTransactionReceipt({ hash });

  const withdraw = useCallback(async (assets: string) => {
    if (!address) return;
    setError(undefined);
    try {
      const parsed = parseUnits(assets, DECIMALS);
      const h = await writeContractAsync({
        address: VAULT_ADDRESS,
        abi: VAULT_ABI,
        functionName: "withdraw",
        args: [parsed, address, address],
      });
      setHash(h);
      return h;
    } catch (e: unknown) {
      setError(e instanceof Error ? e.message : "Transaction failed");
    }
  }, [address, writeContractAsync]);

  return { withdraw, hash, isPending, isConfirming, isSuccess, error };
}
