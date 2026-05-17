"use client";

import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { useJVStats } from "@/hooks/useJVRead";

export function JVStats() {
  const { target, collected, active, isLoading } = useJVStats();

  if (isLoading) {
    return (
      <div className="grid grid-cols-1 md:grid-cols-3 gap-4 w-full max-w-3xl mx-auto">
        {[1, 2, 3].map((i) => (
          <Card key={i}>
            <CardContent className="p-6">
              <div className="h-8 bg-muted animate-pulse rounded" />
            </CardContent>
          </Card>
        ))}
      </div>
    );
  }

  return (
    <div className="w-full max-w-3xl mx-auto space-y-4">
      <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
        <Card>
          <CardHeader className="pb-2">
            <CardTitle className="text-sm font-medium text-muted-foreground">Status</CardTitle>
          </CardHeader>
          <CardContent>
            <span className={`text-lg font-bold ${active ? "text-green-500" : "text-red-500"}`}>
              {active ? "Active" : "Inactive"}
            </span>
          </CardContent>
        </Card>

        <Card>
          <CardHeader className="pb-2">
            <CardTitle className="text-sm font-medium text-muted-foreground">Collected</CardTitle>
          </CardHeader>
          <CardContent>
            <p className="text-2xl font-bold">${collected.toLocaleString()}</p>
          </CardContent>
        </Card>

        <Card>
          <CardHeader className="pb-2">
            <CardTitle className="text-sm font-medium text-muted-foreground">Target</CardTitle>
          </CardHeader>
          <CardContent>
            <p className="text-2xl font-bold">${target.toLocaleString()}</p>
          </CardContent>
        </Card>
      </div>

    </div>
  );
}
