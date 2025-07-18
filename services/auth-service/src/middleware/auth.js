import jwt from 'jsonwebtoken';

export const auth = (req, res, next) => {
  try {
    const authHeader = req.headers.authorization;
    if (!authHeader) {
      console.log('En-tête Authorization manquant');
      return res.status(401).json({ message: 'Token manquant' });
    }

    const token = authHeader.split(' ')[1];
    if (!token) {
      console.log('Token malformé');
      return res.status(401).json({ message: 'Token malformé' });
    }

    //const decoded = jwt.verify(token, process.env.JWT_SECRET || 'test_secret');


    // TEMPORAIRE - avec debug :
    console.log('=== DEBUG MIDDLEWARE ===');
    console.log('JWT_SECRET middleware:', process.env.JWT_SECRET);
    console.log('Fallback utilisé: efrei_super_pass');
    console.log('========================');

    const decoded = jwt.verify(token, process.env.JWT_SECRET || 'efrei_super_pass');
    req.user = decoded;
    next();
  } catch (error) {
    console.error('Erreur dans le middleware auth :', error);
    return res.status(401).json({ message: 'Token invalide' });
  }
};
