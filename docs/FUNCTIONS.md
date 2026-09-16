# Function reference

This build combines a character-graphics banner with a SID pulse arpeggio.

| Function | Responsibility |
|---|---|
| Start | Initializes screen, charset, SID, and raster state. |
| DrawBannerCharGfx | Draws the character-graphics banner and shadow rows. |
| CenterPrintRow / ColorCenteredRowGrey | Centers text and applies the grey row color. |
| Scroller_Tick | Advances the smooth bottom scroller. |
| SID_Init / SID_Tick | Initializes and advances the bounded note sequence. |
| ClearScreen / ClearColor | Resets the screen and color RAM. |

The checked-in charset is versioned with the source.
