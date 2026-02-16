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
import { Shell } from "@/components/layout/Shell";

function Router() {
  return (
    <Shell>
      <Switch>
        <Route path="/" component={Dashboard} />
        <Route path="/projects" component={ProjectList} />
        <Route path="/norms" component={NormsSearch} />
        <Route path="/timeline" component={Timeline} />
        <Route path="/checklists" component={Checklists} />
        <Route path="/documents" component={Documents} />
        <Route path="/documents/:id/analysis" component={DocumentAnalysis} />
        <Route path="/financial" component={Financial} />
        <Route path="/settings" component={ComingSoon} />
        {/* Fallback to 404 */}
        <Route component={NotFound} />
      </Switch>
    </Shell>
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
