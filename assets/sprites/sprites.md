
# Spritesheets
Each spritesheet contains the frames for 1 character class, and they have the following properties

## Macro cells
- Each sheet is 1032x1056 pixels in size and can be considered as 3 rows and 3 columns each being 344x352 pixels in size.
- For each of the 3x3 macro grids the sprites contain the following:
    - In macro cell [1,1] the sprite represents an allied coloured sprite
    - In macro cell [2,1] the sprite represents an enemy coloured sprite
    - In macro cell [3,1] the sprite represents a yellow coloured sprite
    - In macro cell [1,2] the sprite represents a beserk coloured sprite
    - In macro cell [2,2] the sprite represents a zombie coloured sprite
    - In macro cell [3,2] the sprite represents a poisoned coloured sprite
    - In macro cell [1,3] the sprite represents a petrified coloured sprite
    - In macro cell [2,3] the sprite represents character portraits
    - In macro cell [3,3] the cell is blank

- Each of the first 7 macro cells (allied, enemy, yellow, beserk, zombie, poisoned and petrified) have the same sprite layout which is detailed below.

## Single macro cell
For an individual macro cell sized 344x352, they should be considered being made up of 8x8 tiles with the following information.

- the first row is empty
- The following 4 rows should be considered together:
    - The first 4 columns are empty
    - the next 2 columns contain the sprite with a shadow, facing south-west, with their left foot forwards
    - the next column is blank
    - the next 2 columns contain the sprite with a shadow, facing south-west, with their feet together
    - the next column is blank
    - the next 2 columns contain the sprite with a shadow, facing south-west, with their right foot forwards
    - these last 3 sprites represent the player walking south-west
    - The next 4 columns are empty
    - the next 2 columns contain the sprite with a shadow, facing north-west, with their right foot forwards
    - the next column is blank
    - the next 2 columns contain the sprite with a shadow, facing north-west, with their feet together
    - the next column is blank
    - the next 2 columns contain the sprite with a shadow, facing north-west, with their left foot forwards
    - these last 3 sprites represent the player walking north-west
    - the next column is blank
    - the next 2 columns contain the sprite with a shadow, facing south-west in a defensive position
    - the next column is blank
    - the next 2 columns contain the sprite with a shadow, facing north-west in a defensive position
