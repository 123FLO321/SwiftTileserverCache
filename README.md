# SwiftTileserverCache

## Installing

- Install Docker
- Crate a new folder to store the yml file in and change into it: `mkdir TileServer && cd TileServer`
- Load the yml: `wget https://raw.githubusercontent.com/123FLO321/SwiftTileserverCache/master/docker-compose.yml`
- Edit the docker-compose.yml file if you want to change defaults. Default will work fine.
- Crate a new folder to store TileServer data in and chagne into it: `mkdir TileServer && cd TileServer`
- Get Download command from https://openmaptiles.com/downloads/planet/ for your region.
- Download the file using wget.
- Rename file to end in .mbtiles if it got named incorrectly
- Change one layer back into the folder where the docker-compose.yml file is located: `cd ..`
- Start and attach to logs: `docker-compose up -d && docker-compose logs -f`

## Formats

- Tiles: `tile/{style}/{z}/{x}/{y}/{scale}/{format}`
- StaticMap: `static/{style}/{lat}/{lon}/{zoom}/{width}/{height}/{scale}/{format}`

### Style
The default included styles are:
- klokantech-basic
- dark-matter
- positron
-osm-bright
Checkout https://tileserver.readthedocs.io for a guide on how to add more styles.

### Markers
StaticMap route accetps an url-ecoded JSON (check bellow) on markers query parameter. 
Example:
```JSON
[
 {
	"url": "Marker Image URL",
	"height": 50,
	"width": 50,
	"x_offset": 0,
	"y_offset": 0,
	"latitude": 10.0,
	"longitude": 10.0
 },
 …
]
```

## Examples

### Tiles
https://tileserverurl/tile/klokantech-basic/{z}/{x}/{y}/2/png

### StaticMap
https://tileserverurl/static/klokantech-basic/47.263416/11.400512/17/500/500/2/png

### StaticMap with Markers
https://tileserverurl/static/klokantech-basic/47.263416/11.400512/17/500/500/2/png?markers=%5B%7B%22url%22%3A%22https%3A%2F%2Fraw.githubusercontent.com%2Fnileplumb%2FPkmnShuffleMap%2Fmaster%2FNOVA_Sprites%2F201.png%22%2C%22height%22%3A50%2C%22width%22%3A50%2C%22x_offset%22%3A0%2C%22y_offset%22%3A0%2C%22latitude%22%3A%2047.263416%2C%22longitude%22%3A%2011.400512%7D%5D
