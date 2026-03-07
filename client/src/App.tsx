import { Switch, Route } from "wouter";
import { queryClient } from "./lib/queryClient";
import { QueryClientProvider } from "@tanstack/react-query";
import { Toaster } from "@/components/ui/toaster";
import { TooltipProvider } from "@/components/ui/tooltip";
import NotFound from "@/pages/not-found";
import Dashboard from "@/pages/Dashboard";
import ProjectList from "@/pages/ProjectList";
import NormsSearch from "@/pages/NormsSearch";
import Timeline from "@/pages/Timeline";
import Checklists from "@/pages/Checklists";
import Documents from "@/pages/Documents";
import DocumentAnalysis from "@/pages/DocumentAnalysis";
import Financial from "@/pages/Financial";
import ComingSoon from "@/pages/ComingSoon";
import Providers from "@/pages/Providers";
import Landing from "@/pages/Landing";
import { Shell } from "@/components/layout/Shell";

function AppRouter() {
  return (
    <Shell>
      <Switch>
        <Route path="/app" component={Dashboard} />
        <Route path="/app/projects" component={ProjectList} />
        <Route path="/app/norms" component={NormsSearch} />
        <Route path="/app/timeline" component={Timeline} />
        <Route path="/app/checklists" component={Checklists} />
        <Route path="/app/documents" component={Documents} />
        <Route path="/app/documents/:id/analysis" component={DocumentAnalysis} />
        <Route path="/app/financial" component={Financial} />
        <Route path="/app/providers" component={Providers} />
        <Route path="/app/settings" component={ComingSoon} />
        <Route component={NotFound} />
      </Switch>
    </Shell>
  );
}

function Router() {
  return (
    <Switch>
      <Route path="/" component={Landing} />
      <Route path="/app*" component={AppRouter} />
      {/* Fallback to 404 */}
      <Route component={NotFound} />
    </Switch>
  );
}

function App() {
  return (
    <QueryClientProvider client={queryClient}>
      <TooltipProvider>
        <Toaster />
        <Router />
      </TooltipProvider>
    </QueryClientProvider>
  );
}

export default App;
