# ce392_project
Anthony, Nick, Damien raaah


## Architecture

* D8M Image Resolution: 640x480
    * Internal processing resolution: 160x120

### Fixes needed
* Hough.vhd: 
    * Optimize module to meet 100+ MHz timing
    * Need to make sure it is synthesizable
    * Test to make sure it doesn't write to output FIFO if no lines are detected