import { Construction } from "lucide-react";
import { Button } from "@/components/ui/button";
import { Link } from "wouter";

export default function ComingSoon() {
  return (
    <div className="flex flex-col items-center justify-center min-h-[60vh] space-y-6 text-center animate-in fade-in zoom-in duration-500">
      <div className="rounded-full bg-muted/30 p-8 ring-1 ring-border shadow-2xl">
        <Construction className="h-16 w-16 text-muted-foreground" />
      </div>
      <div className="space-y-2 max-w-md">
        <h2 className="text-3xl font-display font-bold">Em Construção</h2>
        <p className="text-muted-foreground">
          Este módulo está sendo desenvolvido e estará disponível na próxima atualização do OwnerControl.
        </p>
      </div>
      <Button asChild>
        <Link href="/">Voltar ao Dashboard</Link>
      </Button>
    </div>
  );
}
