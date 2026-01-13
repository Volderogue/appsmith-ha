# Comment Dokploy gère les applications avec Dockerfile

## 🤔 Question : Comment Dokploy gère-t-il les applications avec juste un Dockerfile ?

### Réponse courte

Dokploy **orchestre automatiquement** les conteneurs sans avoir besoin de docker-compose. Quand vous créez une "Application" dans Dokploy avec un Dockerfile, Dokploy :

1. **Construit l'image** depuis votre Dockerfile
2. **Crée et gère le conteneur** automatiquement
3. **Configure le réseau** pour que les services communiquent
4. **Gère le reverse proxy** et SSL automatiquement
5. **Surveille la santé** des conteneurs

### Architecture Dokploy vs Docker Compose

#### Avec Docker Compose (ce que vous n'utilisez pas)
```yaml
services:
  appsmith:
    build: .
    environment:
      - VAR=value
    volumes:
      - data:/app
    networks:
      - app-network
```

#### Avec Dokploy Application (ce que vous utilisez)
```
Dokploy Interface
    ↓
Application Appsmith
    ├── Dockerfile (votre fichier)
    ├── Variables d'environnement (configurées dans l'UI)
    ├── Volumes (configurés dans l'UI)
    └── Port (configuré dans l'UI)
         ↓
    Dokploy génère automatiquement:
    - docker build -t appsmith:xxx .
    - docker run --name appsmith \
        --env-file .env \
        --volume appsmith-data:/appsmith-stacks \
        --network dokploy-project-network \
        appsmith:xxx
```

## 🔄 Comment Dokploy orchestre les services

### 1. Réseau interne automatique

Quand vous créez plusieurs applications dans le **même projet Dokploy**, elles sont automatiquement sur le **même réseau Docker interne**.

**Exemple concret** :
- Projet Dokploy : `appsmith-project`
- Applications :
  - `mongo` (MongoDB)
  - `redis` (Redis)
  - `appsmith` (Appsmith)

**Résultat** : Tous ces conteneurs peuvent communiquer entre eux via leur nom :
- `mongo:27017` ✅
- `redis:6379` ✅
- `appsmith` peut joindre `mongo` et `redis` ✅

**Comment Dokploy fait ça** :
```bash
# Dokploy crée automatiquement un réseau
docker network create dokploy-appsmith-project

# Et attache tous les conteneurs du projet à ce réseau
docker network connect dokploy-appsmith-project mongo
docker network connect dokploy-appsmith-project redis
docker network connect dokploy-appsmith-project appsmith
```

### 2. Gestion des variables d'environnement

Dans l'interface Dokploy, vous configurez les variables d'environnement. Dokploy les injecte automatiquement dans le conteneur.

**Dans Dokploy UI** :
```
Variables d'environnement:
APPSMITH_MONGODB_URI=mongodb://appsmith:pass@mongo:27017/appsmith
APPSMITH_REDIS_URL=redis://redis:6379
```

**Dokploy génère** :
```bash
docker run \
  -e APPSMITH_MONGODB_URI=mongodb://appsmith:pass@mongo:27017/appsmith \
  -e APPSMITH_REDIS_URL=redis://redis:6379 \
  appsmith:latest
```

### 3. Gestion des volumes

Vous configurez les volumes dans l'UI Dokploy. Dokploy les crée et les monte automatiquement.

**Dans Dokploy UI** :
```
Volumes:
/appsmith-stacks → Volume: appsmith-data (persistent)
```

**Dokploy génère** :
```bash
docker volume create appsmith-data
docker run \
  -v appsmith-data:/appsmith-stacks \
  appsmith:latest
```

### 4. Reverse Proxy automatique

Dokploy intègre un reverse proxy (généralement Traefik ou Nginx) qui :
- Détecte automatiquement les nouveaux conteneurs
- Configure les routes selon le domaine configuré
- Gère SSL/TLS automatiquement (Let's Encrypt)

**Dans Dokploy UI** :
```
Domaine: appsmith.digiconseil.fr
Port: 80
```

**Dokploy configure automatiquement** :
- Route : `appsmith.digiconseil.fr` → `appsmith:80`
- Certificat SSL automatique
- Redirection HTTP → HTTPS

## 🛡️ Haute Disponibilité : Ce qui la garantit

### ✅ Ce qui EST garanti

#### 1. **MongoDB Replica Set** (via template Dokploy)
- ✅ Réplication automatique des données
- ✅ Failover automatique en cas de panne
- ✅ Persistance des données (volumes)

**Comment vérifier** :
```bash
docker exec mongo mongosh --eval "rs.status()"
# Devrait montrer un replica set actif
```

#### 2. **Volumes persistants**
- ✅ Les données survivent aux redémarrages
- ✅ Les volumes sont stockés sur le disque du serveur
- ✅ Pas de perte de données en cas de redémarrage du conteneur

**Comment vérifier** :
```bash
# Créer un fichier dans le volume
docker exec appsmith touch /appsmith-stacks/test.txt

# Redémarrer le conteneur
docker restart appsmith

# Le fichier existe toujours
docker exec appsmith ls /appsmith-stacks/test.txt
```

#### 3. **Health Checks et redémarrage automatique**
- ✅ Dokploy surveille la santé des conteneurs
- ✅ Redémarrage automatique en cas d'échec
- ✅ Configuration `restart: unless-stopped` par défaut

**Comment vérifier** :
```bash
# Arrêter le conteneur
docker stop appsmith

# Dokploy le redémarre automatiquement
docker ps | grep appsmith
# Le conteneur devrait être en cours d'exécution
```

#### 4. **Réseau interne stable**
- ✅ Les conteneurs communiquent via leur nom de service
- ✅ Le réseau persiste même après redémarrage
- ✅ Isolation des autres projets

**Comment vérifier** :
```bash
# Depuis Appsmith, tester la connexion
docker exec appsmith ping -c 3 mongo
docker exec appsmith ping -c 3 redis
```

### ❌ Ce qui N'EST PAS garanti (sans Docker Swarm)

#### 1. **Réplication automatique des conteneurs Appsmith**
- ❌ Pas de réplication automatique (pas de `docker service scale`)
- ❌ Pas de load balancing automatique entre instances

**Solution** :
- Créer manuellement plusieurs instances dans Dokploy
- Utiliser un load balancer externe

#### 2. **Failover automatique au niveau orchestration**
- ❌ Si le serveur Docker tombe, pas de failover automatique
- ❌ Pas de réplication au niveau infrastructure

**Solution** :
- Utiliser plusieurs serveurs avec un load balancer
- Configurer la réplication au niveau base de données (MongoDB Replica Set)

#### 3. **Gestion automatique des nœuds**
- ❌ Pas de cluster Docker Swarm
- ❌ Pas de distribution automatique des conteneurs

## 🔍 Comment vérifier la haute disponibilité

### Checklist de vérification

#### ✅ 1. Vérifier MongoDB Replica Set
```bash
# Se connecter à MongoDB
docker exec -it mongo mongosh

# Vérifier le statut
rs.status()

# Résultat attendu :
# {
#   set: 'rs0',
#   members: [
#     { _id: 0, name: 'mongo:27017', stateStr: 'PRIMARY', health: 1 }
#   ]
# }
```

**✅ Succès si** : `stateStr: 'PRIMARY'` et `health: 1`

#### ✅ 2. Vérifier Redis
```bash
# Tester Redis
docker exec redis redis-cli PING
# Devrait répondre: PONG
```

**✅ Succès si** : Répond `PONG`

#### ✅ 3. Vérifier Appsmith
```bash
# Vérifier que le conteneur tourne
docker ps | grep appsmith

# Vérifier les logs pour les erreurs
docker logs appsmith | grep -i error

# Tester l'application
curl -I https://appsmith.digiconseil.fr
```

**✅ Succès si** : 
- Conteneur en cours d'exécution
- Pas d'erreurs critiques dans les logs
- Application répond (HTTP 200)

#### ✅ 4. Test de résilience MongoDB
```bash
# 1. Arrêter MongoDB
docker stop mongo

# 2. Vérifier les logs Appsmith (devrait montrer des erreurs de connexion)
docker logs -f appsmith

# 3. Redémarrer MongoDB
docker start mongo

# 4. Vérifier qu'Appsmith se reconnecte
# Les erreurs de connexion devraient disparaître
```

**✅ Succès si** : Appsmith se reconnecte automatiquement après le redémarrage de MongoDB

#### ✅ 5. Test de résilience Appsmith
```bash
# 1. Arrêter Appsmith
docker stop appsmith

# 2. Vérifier que Dokploy le redémarre
sleep 10
docker ps | grep appsmith

# 3. Vérifier que l'application répond
curl -I https://appsmith.digiconseil.fr
```

**✅ Succès si** : 
- Dokploy redémarre automatiquement le conteneur
- L'application répond après redémarrage

#### ✅ 6. Vérifier les volumes persistants
```bash
# 1. Créer un fichier de test
docker exec appsmith touch /appsmith-stacks/test-persistence.txt

# 2. Arrêter et supprimer le conteneur (sans supprimer le volume)
docker stop appsmith
docker rm appsmith

# 3. Recréer le conteneur via Dokploy (avec le même volume)

# 4. Vérifier que le fichier existe toujours
docker exec appsmith ls /appsmith-stacks/test-persistence.txt
```

**✅ Succès si** : Le fichier existe toujours après recréation du conteneur

### Script de vérification automatique

Créez un fichier `verify-ha.sh` (voir `HA_VERIFICATION.md` pour le script complet) :

```bash
#!/bin/bash
./verify-ha.sh
```

## 📊 Résumé : Garanties de HA

| Composant | Réplication | Persistance | Redémarrage Auto | Failover |
|-----------|-------------|-------------|------------------|----------|
| **MongoDB** | ✅ Replica Set | ✅ Volume | ✅ Oui | ✅ Oui (replica set) |
| **Redis** | ❌ Non | ✅ Volume | ✅ Oui | ❌ Non |
| **Appsmith** | ❌ Non* | ✅ Volume | ✅ Oui | ❌ Non* |
| **Volumes** | ✅ Oui | ✅ Oui | N/A | N/A |

*Peut être fait manuellement en créant plusieurs instances dans Dokploy

## 🎯 Conclusion

### Ce que Dokploy fait automatiquement :
1. ✅ Orchestration des conteneurs (sans docker-compose)
2. ✅ Réseau interne pour la communication
3. ✅ Reverse proxy et SSL
4. ✅ Health checks et redémarrage automatique
5. ✅ Gestion des volumes persistants

### Ce que vous devez faire manuellement :
1. ⚠️ Créer plusieurs instances Appsmith si vous voulez la réplication
2. ⚠️ Configurer un load balancer externe si nécessaire
3. ⚠️ Surveiller la santé des services
4. ⚠️ Vérifier régulièrement les backups

### Ce qui garantit la HA :
- ✅ **MongoDB Replica Set** : Réplication et failover automatique
- ✅ **Volumes persistants** : Données préservées
- ✅ **Health checks** : Redémarrage automatique
- ✅ **Réseau stable** : Communication fiable entre services

### Ce qui ne garantit PAS la HA (sans Swarm) :
- ❌ Réplication automatique des conteneurs Appsmith
- ❌ Load balancing automatique
- ❌ Failover au niveau infrastructure

**Solution** : Créer manuellement plusieurs instances dans Dokploy et utiliser un load balancer externe.

