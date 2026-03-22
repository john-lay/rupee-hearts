
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
- the next row is empty
- The following 5 rows should be considered together:
    - the first column is blank
    - the next 2 columns contain the sprite facing south-west, with their feet together and both hands above their head
    - the next column is blank
    - the next 2 columns contain the sprite facing south-west, with their left foot forwards
    - the next column is blank
    - the next 2 columns contain the sprite facing south-west, with their feet together
    - the next column is blank
    - the next 2 columns contain the sprite facing south-west, with their right foot forwards
    - these last 3 sprites represent the player walking south-west
    
    - the next column is blank
    - the next 2 columns contain the sprite facing north-west, with their feet together and both hands above their head
    - the next column is blank
    - the next 2 columns contain the sprite facing north-west, with their right foot forwards
    - the next column is blank
    - the next 2 columns contain the sprite facing north-west, with their feet together
    - the next column is blank
    - the next 2 columns contain the sprite facing north-west, with their left foot forwards
    - these last 3 sprites represent the player walking north-west
    
    - the next column is blank
    - the next 2 columns contain the sprite facing south-west in a defensive position
    - the next column is blank
    - the next 2 columns contain the sprite facing north-west in a defensive position

    - the next column is blank
    - the next 2 columns contain the sprite facing south-west with their right hand above their head in a victory pose
    - the next column is blank
    - the next 2 columns contain the sprite facing north-west with their right hand above their head in a victory pose

    - the next column is blank
    - the next 2 columns contain the sprite facing south-west with their head lowered and hands together in an afflicted pose
    - the next column is blank
    - the next 2 columns contain the sprite facing north-west with their head lowered and hands together in an afflicted pose
- the next row is empty
- the next 4 rows should be considered together
- the contain 10 sprites in the same configuration as the above set of sprites but represent the sprite in shallow water
- the next 7 rows are empty
- the next 4 rows should be considered together
    - the first column is blank
    -  the next 2 columns contain the sprite facing south-west, in shallow water, in an afflicted state
    - the next column is blank
    -  the next 2 columns contain the sprite facing north-west, in shallow water, in an afflicted state
    - the next column is blank
    -  the next 2 columns contain the sprite facing south-west, in deep water
    - the next column is blank
    -  the next 2 columns also contain the sprite facing south-west, in deep water
    - these last 2 sprites represent the player walking south-west in deep water
    - the next column is blank
    -  the next 2 columns contain the sprite facing north-west, in deep water
    - the next column is blank
    -  the next 2 columns also contain the sprite facing north-west, in deep water
    - these last 2 sprites represent the player walking north-west in deep water
    - the next column is blank
    -  the next 2 columns contain the sprite facing south-west, in a fallen state in water (frame 1)
    - the next column is blank
    -  the next 2 columns contain the sprite facing north-west, in a fallen state in water (frame 1)
    - the next column is blank
    -  the next 2 columns contain the sprite facing south-west, in a fallen state in water (frame 2)
    - the next column is blank
    -  the next 2 columns contain the sprite facing north-west, in a fallen state in water (frame 2)
    - the next column is blank
    -  the next 2 columns also contain the sprite facing south-west, in a fallen state in water
    - the next column is blank
    -  the next 2 columns also contain the sprite facing north-west, in a fallen state in water
- the next row is empty
- the next 4 rows should be considered together
    - the first column is blank
    - the next 2 columns contain the sprite facing south-west in a taking damage state
    - the next column is blank
    - the next 2 columns contain the sprite facing north-west in a taking damage state
    - the next column is blank
    - the next 2 columns contain the sprite with a shadow, facing south-west in a critical state
    - the next column is blank
    - the next 2 columns contain the sprite with a shadow, facing north-west in a critical state
    - the next column is blank
    - the next 2 columns contain the sprite with a shadow, facing south-west in a fallen state
    - the next column is blank
    - the next 2 columns contain the sprite with a shadow, facing north-west in a fallen state
- the next 2 rows are empty
- the next 4 rows should be considered together
    - the first 2 columns are blank
    - the next 2 columns contains the sprite facing south-west about to attack
    - the next column is blank
    - the next 3 columns contains the sprite facing south-west winding up to attack
    - the next column is blank
    - the next 3 columns contains the sprite facing south-west attacking
    - these last 3 sprites represent the player attacking south-west
    - the next 3 columns are blank
    - the next 2 columns contains the sprite facing north-west about to attack
    - the next column is blank
    - the next 3 columns contains the sprite facing north-west winding up to attack
    - the next column is blank
    - the next 3 columns contains the sprite facing north-west attacking
    - these last 3 sprites represent the player attacking north-west
- the next row is empty
- the next 5 rows should be considered together
    - the next 2 columns contain the sprite facing south-west with their head lowered looking down
    - the next column is blank
    - the next 2 columns contain the sprite facing south-west with their head lowered looking down-right
    - the next column is blank
    - the next 2 columns contain the sprite facing south-west with their head lowered looking down-left
    - the last 3 sprite represent the player looking weary facing south-west
    - the next column is blank

    - the next 2 columns contain the sprite facing north-west with their head lowered looking down
    - the next column is blank
    - the next 2 columns contain the sprite facing north-west with their head lowered looking down-right
    - the next column is blank
    - the next 2 columns contain the sprite facing north-west with their head lowered looking down-left
    - the last 3 sprite represent the player looking weary facing north-west
    - the next column is blank

    - the next 2 columns contain the sprite facing south-west in a defending (weary) pose
    - the next column is blank
    - the next 2 columns contain the sprite facing north-west in a defending (weary) pose
    - the next column is blank

    - the next 2 columns contain the sprite facing south-west with their left hand in a reaching out offering position
    - the next column is blank
    - the next 2 columns contain the sprite facing north-west with their left hand in a reaching out offering position

## portraits
In macro cell [2,3] the contents can be considered being made up of 8x8 tiles with the following information.
- the first row is blank
- the next 8 rows should be considered together
    - the first column is blank
    - the next 6 columns contain the ally portrait
    - the next column in blank
    - the next 6 columns contain the enemy portrait
