# Appsmith HA - Déploiement Haute Disponibilité sur Dokploy

Ce projet contient la configuration pour déployer Appsmith en haute disponibilité sur Dokploy avec réplication de la base de données.

## 📋 Architecture

```
┌─────────────────────────────────────────────────────────┐
│                    Dokploy Project                      │
├─────────────────────────────────────────────────────────┤
│                                                          │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐ │
│  │   MongoDB    │  │    Redis     │  │   Appsmith   │ │
│  │ (ReplicaSet) │  │   (Cache)    │  │   (UI+API)   │ │
│  └──────────────┘  └──────────────┘  └──────────────┘ │
│                                                          │
└─────────────────────────────────────────────────────────┘
```

### Composants

1. **MongoDB** : Base de données principale (déployée via template Dokploy avec réplication)
2. **Redis** : Cache et sessions (déployé séparément dans Dokploy)
3. **Appsmith** : Application principale (UI + Backend) déployée via Dockerfile

## 🚀 Déploiement sur Dokploy

### Prérequis

- Dokploy installé et configuré
- MongoDB déployé avec réplication (via template Dokploy)
- Redis déployé dans le même projet Dokploy
- Accès SSH au serveur Dokploy

### Étape 1 : Préparer MongoDB et Redis

1. **MongoDB** : Utilisez le template Dokploy qui gère la réplication
   - Le template initialise automatiquement le replica set
   - Notez le nom du service MongoDB (ex: `mongo`)

2. **Redis** : Créez une application Redis
   - Image : `redis:6.2-alpine`
   - Port : `6379`
   - Volume persistant pour `/data`
   - Notez le nom du service Redis (ex: `redis`)

### Étape 2 : Déployer Appsmith

1. **Dans Dokploy, créez une nouvelle Application** :
   - Type : **Application** (pas Docker Compose)
   - Source : **Dockerfile** ou **Git Repository**
   - Si Git : Connectez ce repository
   - Si Dockerfile : Uploadez le Dockerfile

2. **Configuration de l'application** :
   - **Port** : `80`
   - **Build Context** : `.` (racine du projet)
   - **Dockerfile** : `Dockerfile`

3. **Variables d'environnement** :
   - Copiez les variables depuis `.env.example`
   - Adaptez les hostnames MongoDB et Redis selon vos noms de services Dokploy
   - **IMPORTANT** : Générez des valeurs sécurisées pour :
     - `APPSMITH_ENCRYPTION_PASSWORD`
     - `APPSMITH_ENCRYPTION_SALT`
     
   ```bash
   # Générer des valeurs sécurisées
   openssl rand -base64 32  # Pour APPSMITH_ENCRYPTION_PASSWORD
   openssl rand -base64 32  # Pour APPSMITH_ENCRYPTION_SALT
   ```

4. **Volumes persistants** :
   - Créez un volume pour `/appsmith-stacks`
   - Ce volume contient toutes les données d'Appsmith (applications, configurations, etc.)

5. **Dépendances** :
   - Configurez les dépendances pour que MongoDB et Redis démarrent avant Appsmith
   - Dans Dokploy, vous pouvez configurer les health checks

### Étape 3 : Configuration du domaine

1. Dans les paramètres de l'application Appsmith :
   - Configurez le domaine (ex: `appsmith.digiconseil.fr`)
   - Dokploy gérera automatiquement le reverse proxy et SSL

2. Mettez à jour les variables d'environnement :
   - `APPSMITH_DOMAIN=https://votre-domaine.com`
   - `APPSMITH_CUSTOM_DOMAIN=https://votre-domaine.com`

## 🔄 Comment Dokploy gère les applications avec Dockerfile

### Sans Docker Compose

Quand vous utilisez uniquement un Dockerfile dans Dokploy :

1. **Dokploy construit l'image** depuis votre Dockerfile
2. **Dokploy crée automatiquement un conteneur** avec :
   - Les variables d'environnement que vous avez configurées
   - Les volumes que vous avez définis
   - Le réseau interne du projet Dokploy
   - Le reverse proxy pour le domaine

3. **Communication entre services** :
   - Tous les services du même projet Dokploy sont sur le même réseau interne
   - Ils peuvent communiquer via leur nom de service
   - Exemple : `mongo:27017`, `redis:6379`

4. **Pas besoin de docker-compose** :
   - Dokploy orchestre les conteneurs automatiquement
   - Chaque application est un conteneur indépendant
   - Les dépendances sont gérées via les health checks et l'ordre de démarrage

## 🛡️ Haute Disponibilité et Réplicabilité

### Ce qui garantit la HA

1. **MongoDB Replica Set** :
   - Le template Dokploy pour MongoDB configure un replica set
   - Les données sont répliquées automatiquement
   - En cas de panne d'un nœud, un autre prend le relais

2. **Volumes persistants** :
   - Les données sont stockées dans des volumes Docker
   - En cas de redémarrage du conteneur, les données sont préservées

3. **Health Checks** :
   - Dokploy surveille la santé des conteneurs
   - Redémarrage automatique en cas de problème

### Réplication Appsmith

Pour répliquer Appsmith lui-même (plusieurs instances) :

1. **Dans Dokploy, créez plusieurs instances de l'application Appsmith** :
   - Même Dockerfile
   - Mêmes variables d'environnement
   - Même volume (partagé) pour `/appsmith-stacks`
   - Ou volumes séparés si vous voulez des environnements différents

2. **Load Balancer** :
   - Dokploy peut configurer un load balancer automatiquement
   - Ou utilisez un reverse proxy externe (Traefik, Nginx)

### Limitations sans Docker Swarm

Sans Docker Swarm, vous ne pouvez pas :
- Répliquer automatiquement les conteneurs avec `docker service scale`
- Utiliser les réseaux overlay natifs de Swarm
- Bénéficier de la réplication automatique au niveau orchestration

**Solutions alternatives** :
- Créer manuellement plusieurs instances dans Dokploy
- Utiliser un load balancer externe
- Configurer la réplication au niveau application (si Appsmith le supporte)

## ✅ Comment vérifier la haute disponibilité

### 1. Vérifier MongoDB Replica Set

```bash
# Se connecter au conteneur MongoDB
docker exec -it <container-mongo> mongosh

# Vérifier le statut du replica set
rs.status()

# Vous devriez voir :
# - _id: "rs0"
# - members avec au moins un PRIMARY
```

### 2. Vérifier Redis

```bash
# Se connecter au conteneur Redis
docker exec -it <container-redis> redis-cli

# Tester la connexion
PING
# Devrait répondre: PONG

# Vérifier les informations
INFO replication
```

### 3. Vérifier Appsmith

```bash
# Vérifier que le conteneur tourne
docker ps | grep appsmith

# Vérifier les logs
docker logs <container-appsmith>

# Tester l'endpoint de santé (si disponible)
curl http://localhost/health
```

### 4. Tests de résilience

1. **Test de redémarrage MongoDB** :
   ```bash
   docker restart <container-mongo>
   # Appsmith devrait continuer à fonctionner après reconnexion
   ```

2. **Test de redémarrage Redis** :
   ```bash
   docker restart <container-redis>
   # Les sessions peuvent être perdues, mais l'app devrait redémarrer
   ```

3. **Test de redémarrage Appsmith** :
   ```bash
   docker restart <container-appsmith>
   # L'application devrait redémarrer et se reconnecter à MongoDB/Redis
   ```

### 5. Monitoring dans Dokploy

- **Dashboard Dokploy** : Surveillez l'état des conteneurs
- **Logs** : Consultez les logs en temps réel
- **Métriques** : Utilisez les métriques Docker (CPU, RAM, réseau)

### 6. Vérification de la réplication MongoDB

```bash
# Dans MongoDB
rs.status()

# Vérifiez :
# - Le nombre de membres (members.length)
# - L'état de chaque membre (stateStr: "PRIMARY" ou "SECONDARY")
# - La santé (health: 1)
```

## 🔧 Dépannage

### Appsmith ne se connecte pas à MongoDB

1. Vérifiez le nom du service MongoDB dans Dokploy
2. Vérifiez que MongoDB est démarré et healthy
3. Vérifiez l'URI MongoDB dans les variables d'environnement
4. Vérifiez les logs : `docker logs <container-appsmith>`

### Appsmith ne se connecte pas à Redis

1. Vérifiez le nom du service Redis dans Dokploy
2. Vérifiez que Redis est démarré
3. Vérifiez l'URL Redis dans les variables d'environnement

### Problèmes de volumes

1. Vérifiez que les volumes sont bien montés : `docker inspect <container>`
2. Vérifiez les permissions : `ls -la /appsmith-stacks`
3. Vérifiez l'espace disque : `df -h`

## 📚 Ressources

- [Documentation Appsmith](https://docs.appsmith.com/)
- [Documentation Dokploy](https://dokploy.com/docs)
- [Documentation MongoDB Replica Set](https://www.mongodb.com/docs/manual/replication/)

## 🔐 Sécurité

- ⚠️ **Changez les mots de passe par défaut** dans MongoDB
- ⚠️ **Générez des valeurs sécurisées** pour les clés de chiffrement
- ⚠️ **Désactivez les inscriptions publiques** dans Appsmith
- ⚠️ **Utilisez HTTPS** (géré automatiquement par Dokploy)
- ⚠️ **Limitez l'accès réseau** aux services nécessaires

## 📝 Notes

- Les volumes doivent être persistants pour préserver les données
- MongoDB doit être initialisé avec un replica set pour la HA
- Appsmith nécessite MongoDB ET Redis pour fonctionner correctement
- Les variables d'environnement sont critiques pour le bon fonctionnement

