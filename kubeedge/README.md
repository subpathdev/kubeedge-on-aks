# KubeEdge aufsetzen und von extern erreichbar machen

1. Service auf LoadBalancer
2. Cloudcore `dnsNames` z.B. unicorn.example.com (nicht advertiseAddress benutzen, da das nur mit IP geht!)
3. DNS Record von unicorn.example.com auf LoadBalancer IP
4. EdgeCore auf auf unicorn.example.com konfigurieren
