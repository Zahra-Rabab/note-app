# How to find a store's internal (unofficial) API

This is how you'll get real prices flowing without writing a browser
automation script. Do this on desktop Chrome or Firefox.

## Steps

1. Open the store's website (e.g. `https://shop.imtiaz.com.pk`).
2. Open DevTools: press `F12` (or right-click → Inspect).
3. Click the **Network** tab.
4. In the filter box, type `fetch/xhr` (or select the "Fetch/XHR" filter) —
   this hides images/CSS and only shows data requests.
5. On the website, use the **search box** to search for a product (e.g.
   "milk"). Watch the Network tab — new requests will appear.
6. Look for a request whose name looks like `search`, `products`,
   `catalog`, etc. Click it.
7. Check the **Response** or **Preview** tab for that request — if you see
   JSON data with product names and prices, you've found it.
8. Click the **Headers** tab for that same request and copy the full
   **Request URL** at the top.
9. Note the shape of the JSON response — specifically:
   - What key(s) lead to the array of products (e.g. `data.products`)
   - What key inside each product holds the name (e.g. `title`)
   - What key inside each product holds the price (e.g. `price`)

## What to send me (or fill into store_configs.json yourself)

- The Request URL (with your search term visible in it, e.g. `...?q=milk`)
- A short snippet of the JSON response (just one product's worth — remove
  anything you don't want to share)
- Whether the page needed you to be logged in to see it (if yes, this gets
  more complex — let me know)

Once I have that, filling in `store_configs.json` takes one minute and the
generic scraper (`generic_json_scraper.py`) handles the rest automatically —
no new code needed.

## Things to keep in mind

- **Check the site's Terms of Service / robots.txt first.** Personal,
  low-frequency use (checking your own shopping list occasionally) is very
  different from running a bulk crawler — stay on the reasonable side of
  that line.
- **Don't hammer the endpoint.** A request per item, once, when you tap
  "Fetch Prices" — not a loop checking every few seconds.
- **APIs can change without notice.** If it stops working, redo steps 1-9.
- **Some sites won't have a clean JSON API** — a few return server-rendered
  HTML even for search, or require a session/auth token. Send me what you
  find either way and I'll tell you the best path for that specific site.
