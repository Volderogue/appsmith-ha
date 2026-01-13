# Dockerfile pour Appsmith - Déploiement Dokploy
# Utilise l'image officielle Appsmith Community Edition

FROM appsmith/appsmith-ce:latest

# L'image officielle Appsmith contient déjà :
# - Le serveur backend Java
# - L'interface utilisateur React
# - Nginx pour servir les fichiers statiques
# - Tous les services nécessaires (supervisord)

# Les variables d'environnement seront configurées dans Dokploy
# Voir .env.example pour la liste complète

# Exposer le port 80 (port par défaut d'Appsmith)
EXPOSE 80

# L'image officielle gère déjà le démarrage via supervisord
# Pas besoin de CMD personnalisé, l'ENTRYPOINT de l'image parente est utilisé

# Labels pour documentation
LABEL maintainer="digiconseil"
LABEL description="Appsmith Community Edition - Plateforme de développement d'applications low-code"
LABEL version="latest"

