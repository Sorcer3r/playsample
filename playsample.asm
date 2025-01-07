.cpu _65c02

// PCM Sample playback test

// call playbackInitialise  with a = sample number to play (0-n)
// call playSample at least every 0.09s(11k) or 0.12s(8k) to keep ahead of FIFO buffer
// playstatus will be zero when sample finished playing

.const eightk       = 21        // playback rate = 8000
.const elevenk      = 27        // playback rate = 11025

.const CHROUT       = $FFD2
.const ISR          = $9F27
.const AUDIO_CTRL   = $9F3B
.const AUDIO_RATE   = $9F3C
.const AUDIO_DATA   = $9F3D

.const AFLOW_FLAG   = $08
.const RESET_FIFO   = $80
.const BUFFER_FULL  = $80
.const BUFFER_EMPTY = $40
.const LOAD_DATA    = $02
.const PLAY_DATA    = $01
.const PLAY_ENDED   = $00

.macro break(){         
    .byte $db
}

* = $22 "zeropage" virtual
playDataPtr:    .word $0000     // $22
playDataEnd:    .word $0000     // $24
playVolume:     .byte $00       // $26
playRate:       .byte $00       // $27
playStatus:     .byte $00       // $28
register1:      .word $0000     // $29
register2:      .word $0000     // $2B

* = $0801

BasicUpstart2(Start)

Start: 
    lda #$00      // 1st sample
nextSample:    
    sta register2
    jsr playbackInitialise

main:
    lda register2
    ora #'0'
    jsr CHROUT
    wai
    jsr playSample
    lda playStatus
    bne main
    
    lda register2
    eor #1
    bra nextSample

end:
    rts    

playSample:
    lda playStatus
    cmp #LOAD_DATA
    bne playBuffer
    lda AUDIO_CTRL
    and #BUFFER_FULL
    bne exitPlay
loadData:
    lda (playDataPtr)
    sta AUDIO_DATA
    lda playDataPtr
    inc
    sta playDataPtr
    bne testEnd
    inc playDataPtr+1
testEnd:
    lda playDataPtr
    cmp playDataEnd
    bne testFIFO
    lda playDataPtr+1
    cmp playDataEnd+1
    bne testFIFO
    dec playStatus
    bra startAudio
testFIFO:
    lda ISR
    and #AFLOW_FLAG
    bne loadData
startAudio:
    lda playVolume
    sta AUDIO_CTRL
    lda playRate
    sta AUDIO_RATE
    bra exitPlay
playBuffer:
    cmp #PLAY_DATA
    bne exitPlay
    lda AUDIO_CTRL
    and #BUFFER_EMPTY
    beq exitPlay
    lda #RESET_FIFO
    sta AUDIO_CTRL
    lda #PLAY_ENDED // = 0
    sta AUDIO_RATE
    sta playStatus 
exitPlay:
    rts

playbackInitialise: //a = sample number to initialise (0-n)
    asl
    tax
    lda SampleTable,x
    sta register1
    lda SampleTable+1,x
    sta register1+1
    ldy #5
init1:
    lda (register1),y
    sta playDataPtr,y
    dey
    bpl init1
    lda #RESET_FIFO
    sta AUDIO_CTRL
    lda #LOAD_DATA
    sta playStatus
    rts

SampleTable:
.word ST0
.word ST1

sampleData:
ST0:            // sound sample 1
.word sound1    // start of sample data
.word _sound1   // end of sample data
.byte 15        // volume  
.byte eightk    // playback rate

ST1:            // sound sample 2
.word sound2    // start of sample data
.word _sound2   // end of sample data
.byte 15        // volume
.byte elevenk   // playback rate


.align $1000
sound1:
.import binary "bark8k.raw"   // sound data (8k sample)
_sound1:

sound2:
//.import binary "springsound.raw"   // sound data (11.025k sample)
.import binary "spr.1.3s.11k.raw"   // sound data (11.025k sample)
_sound2:
