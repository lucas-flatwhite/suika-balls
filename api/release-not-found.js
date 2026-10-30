// A filesystem-first rewrite reaches this function only for missing release files.
module.exports = function releaseNotFound(request, response) {
  response.statusCode = 404;
  response.setHeader('Content-Type', 'text/plain; charset=utf-8');
  response.setHeader('Cache-Control', 'no-store');
  response.setHeader('CDN-Cache-Control', 'no-store');
  response.setHeader('Vercel-CDN-Cache-Control', 'no-store');
  response.end(request.method === 'HEAD' ? undefined : 'Release asset not found.');
};
