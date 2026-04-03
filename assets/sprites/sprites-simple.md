# Simple spritesheets

Each sprite is 1024x1024 pixels in size and contains all the sprites for a single character. 

Assume the spritesheet is made up of cells. Each cell is 32x32 pixels in size.

- the first row is empty
- the following 5 rows should be considered together
    - the first column is empty
    - the next 2 columns contain the sprite facing south-west, with one both hands raised
    - the next column is empty
    - the next 2 columns contain the sprite facing south-west, with their left foot forwards, this is the first frame of the walk animation
    - the next column is empty
    - the next 2 columns contain the sprite facing south-west, with their feet together, this is the second frame of the walk animation
    - the next column is empty
    - the next 2 columns contain the sprite facing south-west, with their right foot forwards, this is the third frame of the walk animation
    - the next column is empty

    - the next 3 columns contain the sprite facing south-west, preparing to attack, this is the first frame of the attack animation
    - the next column is empty
    - the next 3 columns contain the sprite facing south-west, attacking, this is the second frame of the attack animation
    - the next column is empty
    - the next 3 columns contain the sprite facing south-west, following an attack, this is the third frame of the attack animation

- the following 5 rows should be considered together. They contain the same data as the previous 5 rows, but with the sprite facing north-west instead

- the next 5 rows should be considered together
    - the first column is empty
    - the next 2 columns contain the sprite facing south-west, in a defensive pose
    - the next column is empty
    - the next 2 columns contain the sprite facing north-west, in a defensive pose
    - the next column is empty
    - the next 2 columns contain the sprite facing south-west, with one hand raised in a victory pose
    - the next column is empty
    - the next 2 columns contain the sprite facing north-west, with one hand raised in a victory pose

- the following 5 rows should be considered together
    - the first column is empty
    - the next 2 columns contain the sprite facing south-west, with the head down, this is the first frame of the weary animation
    - the next column is empty
    - the next 2 columns contain the sprite facing south-west, with the head down and to the right, this is the second frame of the weary animation
    - the next column is empty
    - the next 2 columns contain the sprite facing south-west, with the head down and to the left, this is the third frame of the weary animation
    - the next 5 columns are empty
    - the next 3 sprites only apply to the flying sprite seriph and no others
    - the next 5 columns have the sprite facing south-east with their wings out stretched horizontally, this is the first frame of the flying animation
    - the next 5 columns have the sprite facing south-east with their wings out stretched vertically, this is the second frame of the flying animation
    - the next 5 columns have the sprite facing south-east with their wings partially folded,  this is the third frame of the flying animation

- the following 5 rows should be considered together. They contain the same data as the previous 5 rows, but with the sprite facing north-west instead

- the next row is blank
- the next 4 rows should be considered together
    - the first column is empty
    - the next 2 columns contain the sprite facing south-west, on one knee, in a weak position
    - the next column is empty
    - the next 2 columns contain the sprite facing north-west, on one knee, in a weak position
    - the next column is empty
    - the next 2 columns contain the sprite facing south-west, lying face down defeated
    - the next column is empty
    - the next 2 columns contain the sprite facing north-west, lying face down defeated

- finally in the top right corner of the sprite sheet is the character portrait. It takes up 7 horizontal cells and 9 vertical cells
