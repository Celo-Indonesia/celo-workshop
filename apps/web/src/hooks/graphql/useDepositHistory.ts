"use client";

import { useState, useEffect } from "react";

const INDEXER_URL = "https://celo-workshop-indexer-production.up.railway.app";

export type DepositEvent = {
  amount: string;
  timestamp: string;
  tokenSymbol: string;
  transactionHash: string;
  member: string;
};

export function useDepositHistory(member?: string) {
  const [items, setItems] = useState<DepositEvent[]>([]);
  const [totalCount, setTotalCount] = useState(0);
  const [isLoading, setIsLoading] = useState(false);

  useEffect(() => {
    if (!member) return;

    setIsLoading(true);

    fetch(INDEXER_URL, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        query: `
          query {
            depositedEvents(
              orderDirection: "desc"
              orderBy: "timestamp"
              where: { member: "${member}" }
            ) {
              totalCount
              items {
                amount
                timestamp
                tokenSymbol
                transactionHash
                member
              }
            }
          }
        `,
      }),
    })
      .then((res) => res.json())
      .then((json) => {
        setItems(json.data.depositedEvents.items);
        setTotalCount(json.data.depositedEvents.totalCount);
      })
      .finally(() => setIsLoading(false));
  }, [member]);

  return { items, totalCount, isLoading };
}
