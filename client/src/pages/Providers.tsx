import { HardHat, Star, Phone, Mail } from "lucide-react";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";

const PROVIDERS_MOCK = [
  { id: 1, name: "Construtora Silva & Filhos", specialty: "Alvenaria e Estrutura", rating: 4.8, phone: "(11) 98765-4321", email: "contato@silva.com", status: "ativo" },
  { id: 2, name: "Elétrica Total Ltda", specialty: "Instalações Elétricas", rating: 4.5, phone: "(11) 91234-5678", email: "eletrica@total.com", status: "ativo" },
  { id: 3, name: "HidroTech Engenharia", specialty: "Hidráulica e Esgoto", rating: 4.7, phone: "(11) 99876-5432", email: "contato@hidrotech.com", status: "ativo" },
  { id: 4, name: "Pintura Express", specialty: "Pintura e Acabamento", rating: 4.2, phone: "(11) 93456-7890", email: "orcamento@pintura.com", status: "pendente" },
];

export default function Providers() {
  return (
    <div className="space-y-6 animate-in fade-in duration-500">
      <div>
        <h2 className="text-2xl font-display font-bold tracking-tight">Prestadores</h2>
        <p className="text-muted-foreground text-sm mt-1">Gerencie os prestadores de serviço da sua obra</p>
      </div>

      <div className="grid gap-4 sm:grid-cols-2">
        {PROVIDERS_MOCK.map((provider) => (
          <Card key={provider.id} className="transition-shadow hover:shadow-md">
            <CardHeader className="pb-3">
              <div className="flex items-start justify-between">
                <CardTitle className="text-base font-semibold">{provider.name}</CardTitle>
                <Badge variant={provider.status === "ativo" ? "default" : "secondary"}>
                  {provider.status}
                </Badge>
              </div>
              <p className="text-sm text-muted-foreground">{provider.specialty}</p>
            </CardHeader>
            <CardContent className="space-y-2 text-sm">
              <div className="flex items-center gap-2 text-yellow-500">
                <Star className="h-4 w-4 fill-current" />
                <span className="font-medium">{provider.rating}</span>
              </div>
              <div className="flex items-center gap-2 text-muted-foreground">
                <Phone className="h-3.5 w-3.5" />
                <span>{provider.phone}</span>
              </div>
              <div className="flex items-center gap-2 text-muted-foreground">
                <Mail className="h-3.5 w-3.5" />
                <span>{provider.email}</span>
              </div>
            </CardContent>
          </Card>
        ))}
      </div>
    </div>
  );
}
