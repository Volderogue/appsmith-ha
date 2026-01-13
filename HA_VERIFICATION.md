# Guide de Vérification de la Haute Disponibilité

Ce document explique comment vérifier que votre déploiement Appsmith est bien configuré pour la haute disponibilité.

## 🎯 Objectifs de la HA

1. **Résilience** : L'application continue de fonctionner en cas de panne d'un composant
2. **Réplication des données** : Les données sont dupliquées pour éviter la perte
3. **Récupération automatique** : Les services redémarrent automatiquement en cas d'échec

## 📊 Checklist de Vérification

### ✅ 1. MongoDB Replica Set

#### Vérification du statut

```bash
# Se connecter au conteneur MongoDB
docker exec -it <nom-container-mongo> mongosh

# Vérifier le statut du replica set
rs.status()
```

**Résultat attendu** :
```javascript
{
  set: 'rs0',
  members: [
    {
      _id: 0,
      name: 'mongo:27017',
      stateStr: 'PRIMARY',  // ✅ Doit être PRIMARY
      health: 1,            // ✅ Doit être 1 (healthy)
      uptime: 12345
    }
  ]
}
```

#### Vérification de la réplication

```bash
# Dans mongosh
rs.conf()
```

**Vérifiez** :
- `_id: "rs0"` est présent
- Au moins un membre est configuré
- Le membre est marqué comme PRIMARY

#### Test de résilience MongoDB

```bash
# 1. Arrêter MongoDB
docker stop <container-mongo>

# 2. Vérifier que Appsmith détecte la déconnexion (logs)
docker logs -f <container-appsmith>

# 3. Redémarrer MongoDB
docker start <container-mongo>

# 4. Vérifier qu'Appsmith se reconnecte automatiquement
# Les logs devraient montrer une reconnexion réussie
```

**✅ Succès si** : Appsmith se reconnecte automatiquement à MongoDB après le redémarrage.

### ✅ 2. Redis

#### Vérification de base

```bash
# Se connecter au conteneur Redis
docker exec -it <nom-container-redis> redis-cli

# Test de connexion
PING
# Devrait répondre: PONG

# Vérifier les informations
INFO server
INFO memory
```

**Résultat attendu** :
- `PING` retourne `PONG`
- Redis répond aux commandes
- Pas d'erreurs dans les logs

#### Test de résilience Redis

```bash
# 1. Arrêter Redis
docker stop <container-redis>

# 2. Vérifier les logs Appsmith
docker logs -f <container-appsmith>
# Devrait montrer des erreurs de connexion Redis

# 3. Redémarrer Redis
docker start <container-redis>

# 4. Vérifier la reconnexion
docker logs <container-appsmith>
# Les erreurs Redis devraient disparaître
```

**✅ Succès si** : Appsmith se reconnecte à Redis après le redémarrage.

### ✅ 3. Appsmith

#### Vérification de l'état

```bash
# Vérifier que le conteneur tourne
docker ps | grep appsmith

# Vérifier les logs pour les erreurs
docker logs <container-appsmith> | grep -i error

# Vérifier la santé (si endpoint disponible)
curl -f http://localhost/health || echo "Health endpoint non disponible"
```

#### Vérification des connexions

Dans les logs Appsmith, vous devriez voir :
```
✅ Connected to MongoDB
✅ Connected to Redis
✅ Application started successfully
```

#### Test de résilience Appsmith

```bash
# 1. Arrêter Appsmith
docker stop <container-appsmith>

# 2. Vérifier que Dokploy le redémarre automatiquement
docker ps | grep appsmith
# Le conteneur devrait être en cours de redémarrage

# 3. Attendre quelques secondes
sleep 10

# 4. Vérifier que l'application répond
curl -I https://appsmith.digiconseil.fr
# Devrait retourner HTTP 200
```

**✅ Succès si** : 
- Dokploy redémarre automatiquement le conteneur
- L'application répond après le redémarrage
- Les données sont préservées (connexion à MongoDB/Redis)

### ✅ 4. Volumes Persistants

#### Vérification des volumes

```bash
# Lister les volumes
docker volume ls | grep appsmith

# Inspecter le volume
docker volume inspect <nom-volume-appsmith>

# Vérifier le montage dans le conteneur
docker inspect <container-appsmith> | grep -A 10 Mounts
```

**Vérifiez** :
- Le volume existe
- Le volume est bien monté sur `/appsmith-stacks`
- Le volume a un driver (local ou autre)

#### Test de persistance

```bash
# 1. Créer un fichier de test dans le volume
docker exec <container-appsmith> touch /appsmith-stacks/test-file.txt

# 2. Arrêter et supprimer le conteneur (sans supprimer le volume)
docker stop <container-appsmith>
docker rm <container-appsmith>

# 3. Recréer le conteneur avec le même volume
# (via Dokploy ou manuellement)

# 4. Vérifier que le fichier existe toujours
docker exec <nouveau-container-appsmith> ls -la /appsmith-stacks/test-file.txt
```

**✅ Succès si** : Le fichier existe toujours après la recréation du conteneur.

### ✅ 5. Réseau et Communication

#### Vérification de la connectivité

```bash
# Depuis le conteneur Appsmith, tester la connexion à MongoDB
docker exec <container-appsmith> ping -c 3 mongo

# Tester la connexion à Redis
docker exec <container-appsmith> ping -c 3 redis

# Tester le port MongoDB
docker exec <container-appsmith> nc -zv mongo 27017

# Tester le port Redis
docker exec <container-appsmith> nc -zv redis 6379
```

**✅ Succès si** : 
- Les ping fonctionnent
- Les ports sont accessibles
- Pas de timeouts

#### Vérification du réseau Dokploy

```bash
# Lister les réseaux
docker network ls

# Inspecter le réseau du projet Dokploy
docker network inspect <nom-reseau-dokploy>

# Vérifier que tous les conteneurs sont sur le même réseau
docker network inspect <nom-reseau-dokploy> | grep -A 5 Containers
```

**Vérifiez** :
- Tous les conteneurs (MongoDB, Redis, Appsmith) sont sur le même réseau
- Le réseau permet la communication entre conteneurs

## 🔍 Scripts de Vérification Automatique

### Script complet de vérification

Créez un fichier `verify-ha.sh` :

```bash
#!/bin/bash

echo "🔍 Vérification de la Haute Disponibilité Appsmith"
echo "=================================================="

# Couleurs
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Fonction de vérification
check_service() {
    local service=$1
    if docker ps | grep -q "$service"; then
        echo -e "${GREEN}✅ $service est en cours d'exécution${NC}"
        return 0
    else
        echo -e "${RED}❌ $service n'est pas en cours d'exécution${NC}"
        return 1
    fi
}

# Vérifier les services
echo ""
echo "1. Vérification des services..."
check_service "mongo"
check_service "redis"
check_service "appsmith"

# Vérifier MongoDB Replica Set
echo ""
echo "2. Vérification MongoDB Replica Set..."
MONGO_CONTAINER=$(docker ps | grep mongo | awk '{print $1}' | head -1)
if [ -n "$MONGO_CONTAINER" ]; then
    RS_STATUS=$(docker exec $MONGO_CONTAINER mongosh --quiet --eval "rs.status().ok" 2>/dev/null)
    if [ "$RS_STATUS" = "1" ]; then
        echo -e "${GREEN}✅ MongoDB Replica Set est actif${NC}"
    else
        echo -e "${YELLOW}⚠️  MongoDB Replica Set n'est pas initialisé${NC}"
    fi
else
    echo -e "${RED}❌ Conteneur MongoDB introuvable${NC}"
fi

# Vérifier Redis
echo ""
echo "3. Vérification Redis..."
REDIS_CONTAINER=$(docker ps | grep redis | awk '{print $1}' | head -1)
if [ -n "$REDIS_CONTAINER" ]; then
    REDIS_PING=$(docker exec $REDIS_CONTAINER redis-cli PING 2>/dev/null)
    if [ "$REDIS_PING" = "PONG" ]; then
        echo -e "${GREEN}✅ Redis répond correctement${NC}"
    else
        echo -e "${RED}❌ Redis ne répond pas${NC}"
    fi
else
    echo -e "${RED}❌ Conteneur Redis introuvable${NC}"
fi

# Vérifier les volumes
echo ""
echo "4. Vérification des volumes..."
if docker volume ls | grep -q "appsmith"; then
    echo -e "${GREEN}✅ Volume Appsmith existe${NC}"
else
    echo -e "${RED}❌ Volume Appsmith introuvable${NC}"
fi

if docker volume ls | grep -q "mongo"; then
    echo -e "${GREEN}✅ Volume MongoDB existe${NC}"
else
    echo -e "${RED}❌ Volume MongoDB introuvable${NC}"
fi

if docker volume ls | grep -q "redis"; then
    echo -e "${GREEN}✅ Volume Redis existe${NC}"
else
    echo -e "${RED}❌ Volume Redis introuvable${NC}"
fi

# Vérifier la connectivité réseau
echo ""
echo "5. Vérification de la connectivité..."
APPSMITH_CONTAINER=$(docker ps | grep appsmith | awk '{print $1}' | head -1)
if [ -n "$APPSMITH_CONTAINER" ]; then
    if docker exec $APPSMITH_CONTAINER ping -c 1 mongo >/dev/null 2>&1; then
        echo -e "${GREEN}✅ Appsmith peut joindre MongoDB${NC}"
    else
        echo -e "${RED}❌ Appsmith ne peut pas joindre MongoDB${NC}"
    fi
    
    if docker exec $APPSMITH_CONTAINER ping -c 1 redis >/dev/null 2>&1; then
        echo -e "${GREEN}✅ Appsmith peut joindre Redis${NC}"
    else
        echo -e "${RED}❌ Appsmith ne peut pas joindre Redis${NC}"
    fi
fi

echo ""
echo "=================================================="
echo "✅ Vérification terminée"
```

## 📈 Monitoring Continu

### Recommandations

1. **Surveillance des logs** :
   ```bash
   # Surveiller les logs en temps réel
   docker logs -f <container-appsmith>
   ```

2. **Métriques Docker** :
   ```bash
   # Statistiques des conteneurs
   docker stats
   ```

3. **Health Checks** :
   - Configurez des health checks dans Dokploy
   - Surveillez les alertes dans le dashboard Dokploy

4. **Alertes** :
   - Configurez des alertes pour les redémarrages de conteneurs
   - Surveillez l'utilisation des ressources (CPU, RAM, disque)

## 🎯 Critères de Succès

Votre déploiement est considéré comme HA si :

- ✅ MongoDB Replica Set est actif et fonctionnel
- ✅ Redis répond et est accessible
- ✅ Appsmith se connecte à MongoDB et Redis
- ✅ Les volumes sont persistants
- ✅ Les services redémarrent automatiquement en cas d'échec
- ✅ Les données sont préservées après redémarrage
- ✅ La communication réseau fonctionne entre tous les services

## ⚠️ Limitations sans Docker Swarm

Sans Docker Swarm, vous ne bénéficiez pas de :
- Réplication automatique des conteneurs
- Load balancing automatique
- Gestion automatique des nœuds

**Solutions** :
- Créer manuellement plusieurs instances dans Dokploy
- Utiliser un load balancer externe (Nginx, Traefik)
- Surveiller manuellement la santé des services

