// ===================================
// Script d'initialisation MongoDB
// ===================================

// Créer les utilisateurs pour chaque base de données
print('Initialisation des bases de données MongoDB...');

// Base de données Auth
db = db.getSiblingDB('authdb');
db.createUser({
  user: 'authuser',
  pwd: 'authpass',
  roles: [
    {
      role: 'readWrite',
      db: 'authdb'
    }
  ]
});

// Collection users avec index sur email
db.users.createIndex({ "email": 1 }, { unique: true });
print('Base de données authdb initialisée');

// Base de données Products
db = db.getSiblingDB('productsdb');
db.createUser({
  user: 'productuser',
  pwd: 'productpass',
  roles: [
    {
      role: 'readWrite',
      db: 'productsdb'
    }
  ]
});

// Collections products et carts avec index
db.products.createIndex({ "name": 1 });
db.products.createIndex({ "price": 1 });
db.carts.createIndex({ "userId": 1 }, { unique: true });
print('Base de données productsdb initialisée');

// Base de données Orders
db = db.getSiblingDB('ordersdb');
db.createUser({
  user: 'orderuser',
  pwd: 'orderpass',
  roles: [
    {
      role: 'readWrite',
      db: 'ordersdb'
    }
  ]
});

// Collection orders avec index
db.orders.createIndex({ "userId": 1 });
db.orders.createIndex({ "status": 1 });
db.orders.createIndex({ "createdAt": 1 });
print('Base de données ordersdb initialisée');

print('Initialisation MongoDB terminée avec succès!');