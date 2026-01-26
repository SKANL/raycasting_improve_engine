#version 460 core

#include <flutter/runtime_effect.glsl>

uniform vec2 uResolution;
uniform float uTime;
uniform vec2 uPlayerPos;
uniform float uPlayerDir;
uniform sampler2D uMap;
uniform sampler2D uAtlas;

out vec4 fragColor;

uniform float uFov;
uniform float uPitch;
uniform vec4 uAmbientLight; // r,g,b, unused

struct Light {
    vec2 pos;      
    float radius; 
    vec3 color;    
    float intensity;
};

const int MAX_LIGHTS = 8;
uniform vec4 uLightingParams; // x = uLightCount, yzw = unused
uniform vec4 uLightData[MAX_LIGHTS * 2]; 

const int MAX_STEPS = 64;
// Flutter compilers sometimes struggle with struct arrays in uniforms, so packing into vec4 arrays is safer.
// Layout:
// uLightData[i*2 + 0] = vec4(pos.x, pos.y, radius, intensity)
// uLightData[i*2 + 1] = vec4(r, g, b, 0.0)

const float MAP_SIZE = 32.0;

// Atlas Settings
const float TILE_SIZE = 32.0;
const float ATLAS_SIZE = 128.0;
const float TILES_PER_ROW = 4.0;

void main() {
    vec2 pos = FlutterFragCoord().xy;
    vec2 uv = pos / uResolution;

    // 1. Ray Calculation
    vec2 plane = vec2(-sin(uPlayerDir), cos(uPlayerDir)) * uFov;
    vec2 dir = vec2(cos(uPlayerDir), sin(uPlayerDir));
    float cameraX = 2.0 * uv.x - 1.0;
    vec2 rayDir = dir + plane * cameraX;

    // 2. Map Setup
    vec2 mapPos = floor(uPlayerPos);
    vec2 deltaDist = abs(1.0 / rayDir);
    vec2 stepDir;
    vec2 sideDist;
    
    if (rayDir.x < 0) {
        stepDir.x = -1.0;
        sideDist.x = (uPlayerPos.x - mapPos.x) * deltaDist.x;
    } else {
        stepDir.x = 1.0;
        sideDist.x = (mapPos.x + 1.0 - uPlayerPos.x) * deltaDist.x;
    }
    
    if (rayDir.y < 0) {
        stepDir.y = -1.0;
        sideDist.y = (uPlayerPos.y - mapPos.y) * deltaDist.y;
    } else {
        stepDir.y = 1.0;
        sideDist.y = (mapPos.y + 1.0 - uPlayerPos.y) * deltaDist.y;
    }

    // 3. DDA Loop
    bool hit = false;
    float side = 0.0;
    float wallType = 0.0;
    
    for (int i = 0; i < MAX_STEPS; i++) {
        if (sideDist.x < sideDist.y) {
            sideDist.x += deltaDist.x;
            mapPos.x += stepDir.x;
            side = 0.0;
        } else {
            sideDist.y += deltaDist.y;
            mapPos.y += stepDir.y;
            side = 1.0;
        }
        
        vec2 mapUV = (mapPos + 0.5) / MAP_SIZE;
        
        if (mapUV.x < 0.0 || mapUV.x >= 1.0 || mapUV.y < 0.0 || mapUV.y >= 1.0) {
            hit = true; 
            break;
        }

        vec4 cellData = texture(uMap, mapUV);
        if (cellData.r * 255.0 > 0.5) {
            hit = true;
            wallType = cellData.r * 255.0; 
            wallType = floor(wallType + 0.1);
            break;
        }
    }
    
    // 4. Drawing & Texturing
    float perpWallDist;
    if (side == 0.0) {
        perpWallDist = (sideDist.x - deltaDist.x);
    } else {
        perpWallDist = (sideDist.y - deltaDist.y);
    }
    
    if (hit) {
        float lineHeight = uResolution.y / perpWallDist;
        float drawStart = -lineHeight / 2.0 + uResolution.y / 2.0 + uPitch;
        float drawEnd = lineHeight / 2.0 + uResolution.y / 2.0 + uPitch;
        
        if (pos.y >= drawStart && pos.y <= drawEnd) {
             // Wall Texture Calculation
             float wallX; 
             if (side == 0.0) {
                wallX = uPlayerPos.y + perpWallDist * rayDir.y;
             } else {
                wallX = uPlayerPos.x + perpWallDist * rayDir.x;
             }
             wallX -= floor(wallX);
             
             // Texture Coordinate
             float texX = wallX * TILE_SIZE;
             if (side == 0.0 && rayDir.x > 0) texX = TILE_SIZE - texX - 1.0;
             if (side == 1.0 && rayDir.y < 0) texX = TILE_SIZE - texX - 1.0;
             
             // Simple linear mapping for Y with support for pitch
             float texY = (pos.y - drawStart) / (drawEnd - drawStart) * TILE_SIZE;
             
             // Clamp texY
             texY = clamp(texY, 0.0, TILE_SIZE - 0.1);
             
             // Select Tile from Atlas
             float slotIdx = 1.0; 
             
             float tileX = mod(slotIdx, TILES_PER_ROW);
             float tileY = floor(slotIdx / TILES_PER_ROW);
             
             vec2 atlasUV = vec2(
                 (tileX * TILE_SIZE + texX) / ATLAS_SIZE,
                 (tileY * TILE_SIZE + texY) / ATLAS_SIZE
             );
             
             vec4 texColor = texture(uAtlas, atlasUV);
             
             // Apply lighting
             vec3 lighting = uAmbientLight.rgb;
             
             // Calculate world position of the specific wall pixel
             vec2 hitPos;
             if (side == 0.0) {
                 hitPos = vec2(wallX + mapPos.x, mapPos.y + wallX); // Approximate? No.
                 // Correct logic:
                 // if side==0 (North/South hit), x is changing, y is integer (mapPos.y or mapPos.y+1)
                 // mapPos is the CELL integer coordinate.
                 if (rayDir.x > 0) hitPos.x = mapPos.x; else hitPos.x = mapPos.x + 1.0; 
                 hitPos.y = uPlayerPos.y + perpWallDist * rayDir.y;
             } else {
                 if (rayDir.y > 0) hitPos.y = mapPos.y; else hitPos.y = mapPos.y + 1.0;
                 hitPos.x = uPlayerPos.x + perpWallDist * rayDir.x;
             }
             // Actually, 'wallX' calculated earlier IS the fractional part along the wall.
             // We can reconstruct exact world pos.
             if (side == 0.0) { // Vert line (x constant)
                 hitPos.x = (stepDir.x > 0) ? mapPos.x : mapPos.x + 1.0;
                 hitPos.y = uPlayerPos.y + perpWallDist * rayDir.y;
             } else { // Horiz line (y constant)
                 hitPos.y = (stepDir.y > 0) ? mapPos.y : mapPos.y + 1.0;
                 hitPos.x = uPlayerPos.x + perpWallDist * rayDir.x;
             }

             for (int i = 0; i < MAX_LIGHTS; i++) {
                 if (i >= int(uLightingParams.x)) break;
                 vec4 d1 = uLightData[i * 2];
                 vec4 d2 = uLightData[i * 2 + 1];
                 
                 vec2 lightPos = d1.xy;
                 float radius = d1.z;
                 float intensity = d1.w;
                 vec3 color = d2.rgb;
                 
                 float dist = distance(hitPos, lightPos);
                 if (dist < radius) {
                     float att = 1.0 - (dist / radius);
                     att = att * att; // Quadratic falloff look
                     lighting += color * intensity * att;
                 }
             }

             // Directional shade for walls
             if (side == 1.0) lighting *= 0.7; 
             
             fragColor = vec4(texColor.rgb * lighting, 1.0);

        } else if (pos.y < drawStart) {
             fragColor = vec4(0.1, 0.1, 0.1, 1.0); // Ceiling
        } else {
             fragColor = vec4(0.2, 0.2, 0.2, 1.0); // Floor
        }

    } else {
        fragColor = vec4(0.0, 0.0, 0.0, 1.0);
    }
}
