# Agent Context: Performance Limits & Constraints

## Hard Numbers (Budgets)

To guarantee 60 FPS on mobile, we define strict limits:

1.  **Map Size**:
    - Maximum: **128x128** cells. (16,384 cells).
    - Reason: Larger texture sampling in DDA loop exponentially increases cache misses.

2.  **View Distance (Ray Max Steps)**:
    - Maximum: **32 cells** radius.
    - Shader Implementation: `for (int i=0; i<32; i++)`. Loops must be unrolled or strictly compiled. Infinite distance is banned.

3.  **Entity Count**:
    - Active Physics Entities: **50**.
    - Visible Sprites (Raycast): **20**. Sort by distance and cull the rest before sending to shader.

4.  **Texture Atlas**:
    - Max Size: **2048x2048**. Device compatibility cutoff.
    - No runtime resizing.

## Fail-Safes

- If `dt` (delta time) > 100ms (lag spike), clamp it to 32ms. Do not let physics tunnel through walls due to massive lag.
