const C = 'dutch5k-v107';
self.addEventListener('install', e => { self.skipWaiting(); });
self.addEventListener('activate', e => { e.waitUntil(self.clients.claim()); });
self.addEventListener('fetch', e => {
  const url = e.request.url;
  // never cache the Anthropic API
  if(url.includes('api.anthropic.com')) return;
  e.respondWith(
    caches.open(C).then(cache =>
      cache.match(e.request).then(hit => {
        const net = fetch(e.request).then(resp => {
          if(resp && resp.status===200 && (e.request.method==='GET')){ cache.put(e.request, resp.clone()); }
          return resp;
        }).catch(()=> hit);
        return hit || net;
      })
    )
  );
});
// Tapping the reminder notification focuses/opens the app.
self.addEventListener('notificationclick', e => {
  e.notification.close();
  e.waitUntil(
    self.clients.matchAll({type:'window', includeUncontrolled:true}).then(cls => {
      for(const c of cls){ if('focus' in c) return c.focus(); }
      if(self.clients.openWindow) return self.clients.openWindow('/');
    })
  );
});
