sinon = require 'sinon'
{moves} = require('../data/bw')
{Battle, Pokemon, Status, VolatileStatus, Attachment} = require('../').server
{Factory} = require './factory'
should = require 'should'
shared = require './shared'
itemTests = require './bw/items'
moveTests = require './bw/moves'

describe 'Mechanics', ->
  describe 'a move being made', ->
    it "gets recorded as the battle's last move", ->
      shared.create.call this,
        team1: [Factory('Celebi')]
        team2: [Factory('Magikarp')]

      @battle.makeMove(@player1, 'tackle')
      @battle.makeMove(@player2, 'splash')

      should.exist @battle.lastMove
      @battle.lastMove.should.equal moves['splash']

  describe 'an attack missing', ->
    it 'deals no damage', ->
      shared.create.call this,
        team1: [Factory('Celebi')]
        team2: [Factory('Magikarp')]
      move = moves['leaf-storm']
      sinon.stub(move, 'willMiss', -> true)
      defender = @team2.at(0)
      originalHP = defender.currentHP
      @battle.makeMove(@player1, 'leaf-storm')
      @battle.continueTurn()
      defender.currentHP.should.equal originalHP
      move.willMiss.restore()

    it 'triggers effects dependent on the move missing', ->
      shared.create.call this,
        team1: [Factory('Hitmonlee')]
        team2: [Factory('Magikarp')]
      move = moves['hi-jump-kick']
      sinon.stub(move, 'willMiss', -> true)
      mock = sinon.mock(move)
      mock.expects('afterMiss').once()
      @battle.makeMove(@player1, 'hi-jump-kick')
      @battle.continueTurn()
      mock.verify()
      mock.restore()
      move.willMiss.restore()

    it 'does not trigger effects dependent on the move hitting', ->
      shared.create.call this,
        team1: [Factory('Celebi')]
        team2: [Factory('Gyarados')]
      move = moves['hi-jump-kick']
      sinon.stub(move, 'willMiss', -> true)
      mock = sinon.mock(move)
      mock.expects('afterSuccessfulHit').never()
      @battle.makeMove(@player1, 'leaf-storm')
      @battle.continueTurn()
      mock.verify()
      mock.restore()
      move.willMiss.restore()

  describe 'an attack with 0 accuracy', ->
    it 'can never miss', ->
      shared.create.call this,
        team1: [Factory('Celebi')]
        team2: [Factory('Gyarados')]
      hp = @team2.at(0).currentHP
      @battle.makeMove(@player1, 'aerial-ace')
      @battle.continueTurn()
      @team2.at(0).currentHP.should.be.below hp

  describe 'accuracy and evasion boosts', ->
    it 'heighten and lower the chances of a move hitting', ->
      shared.create.call this,
        team1: [Factory('Hitmonlee')]
        team2: [Factory('Magikarp')]
      shared.biasRNG.call(this, 'randInt', 'miss', 50)

      move = moves['mach-punch']
      mock = sinon.mock(move).expects('afterMiss').once()
      @team2.at(0).boost(evasion: 6)
      @battle.makeMove(@player1, 'mach-punch')
      @battle.continueTurn()
      mock.verify()
      move.afterMiss.restore()

      mock = sinon.mock(move).expects('afterSuccessfulHit').once()
      @team1.at(0).boost(accuracy: 6)
      @battle.makeMove(@player1, 'mach-punch')
      @battle.continueTurn()
      mock.verify()
      move.afterSuccessfulHit.restore()

  describe 'fainting', ->
    it 'forces a new pokemon to be picked', ->
      shared.create.call this,
        team1: [Factory('Mew'), Factory('Heracross')]
        team2: [Factory('Hitmonchan'), Factory('Heracross')]
      @team2.at(0).currentHP = 1
      spy = sinon.spy(@player2, 'emit')
      @battle.makeMove(@player1, 'Psychic')
      @battle.makeMove(@player2, 'Mach Punch')
      spy.calledWith('request action').should.be.true

    it 'does not increment the turn count', ->
      shared.create.call this,
        team1: [Factory('Mew'), Factory('Heracross')]
        team2: [Factory('Hitmonchan'), Factory('Heracross')]
      turn = @battle.turn
      @team2.at(0).currentHP = 1
      @battle.makeMove(@player1, 'Psychic')
      @battle.makeMove(@player2, 'Mach Punch')
      @battle.turn.should.not.equal turn + 1

    it 'removes the fainted pokemon from the action priority queue', ->
      shared.create.call this,
        team1: [Factory('Mew'), Factory('Heracross')]
        team2: [Factory('Hitmonchan'), Factory('Heracross')]
      turn = @battle.turn
      @team1.at(0).currentHP = 1
      @team2.at(0).currentHP = 1
      @battle.makeMove(@player1, 'Psychic')
      @battle.makeMove(@player2, 'Mach Punch')
      @team1.at(0).currentHP.should.be.below 1
      @team2.at(0).currentHP.should.equal 1

    it 'lets the player switch in a new pokemon', ->
      shared.create.call this,
        team1: [Factory('Mew'), Factory('Heracross')]
        team2: [Factory('Hitmonchan'), Factory('Heracross')]
      @team2.at(0).currentHP = 1
      @battle.makeMove(@player1, 'Psychic')
      @battle.makeMove(@player2, 'Mach Punch')
      @battle.makeSwitchByName(@player2, 'Heracross')
      @team2.at(0).name.should.equal 'Heracross'

  describe 'secondary effect attacks', ->
    it 'can inflict effect on successful hit', ->
      shared.create.call this,
        team1: [Factory('Porygon-Z')]
        team2: [Factory('Porygon-Z')]
      shared.biasRNG.call(this, 'next', 'secondary effect', 0)  # 100% chance
      defender = @team2.at(0)
      @battle.makeMove(@player1, 'Iron Head')
      @battle.continueTurn()
      defender.hasAttachment(VolatileStatus.FLINCH).should.be.true

  describe 'secondary status attacks', ->
    it 'can inflict effect on successful hit', ->
      shared.create.call this,
        team1: [Factory('Porygon-Z')]
        team2: [Factory('Porygon-Z')]
      shared.biasRNG.call(this, "next", 'secondary status', 0)  # 100% chance
      defender = @team2.at(0)
      @battle.makeMove(@player1, 'flamethrower')
      @battle.continueTurn()
      defender.hasStatus(Status.BURN).should.be.true

  describe 'the fang attacks', ->
    it 'can inflict two effects at the same time', ->
      shared.create.call this,
        team1: [Factory('Gyarados')]
        team2: [Factory('Gyarados')]
      shared.biasRNG.call(this, "next", "fang status", 0)  # 100% chance
      shared.biasRNG.call(this, "next", "fang flinch", 0)
      defender = @team2.at(0)
      @battle.makeMove(@player1, 'ice-fang')
      @battle.continueTurn()
      defender.hasAttachment(VolatileStatus.FLINCH).should.be.true
      defender.hasStatus(Status.FREEZE).should.be.true

  describe 'a pokemon with technician', ->
    it "doesn't increase damage if the move has bp > 60", ->
      shared.create.call this,
        team1: [Factory('Hitmonchan')]
        team2: [Factory('Mew')]
      @battle.makeMove(@player1, 'Ice Punch')
      hp = @team2.at(0).currentHP
      @battle.continueTurn()
      (hp - @team2.at(0).currentHP).should.equal 84

    it "increases damage if the move has bp <= 60", ->
      shared.create.call this,
        team1: [Factory('Hitmonchan')]
        team2: [Factory('Shaymin (land)')]
      @battle.makeMove(@player1, 'Bullet Punch')
      hp = @team2.at(0).currentHP
      @battle.continueTurn()
      (hp - @team2.at(0).currentHP).should.equal 67

  describe 'STAB', ->
    it "gets applied if the move and user share a type", ->
      shared.create.call this,
        team1: [Factory('Heracross')]
        team2: [Factory('Regirock')]
      @battle.makeMove(@player1, 'Megahorn')
      hp = @team2.at(0).currentHP
      @battle.continueTurn()
      (hp - @team2.at(0).currentHP).should.equal 123

    it "doesn't get applied if the move and user are of different types", ->
      shared.create.call this,
        team1: [Factory('Hitmonchan')]
        team2: [Factory('Mew')]
      @battle.makeMove(@player1, 'Ice Punch')
      hp = @team2.at(0).currentHP
      @battle.continueTurn()
      (hp - @team2.at(0).currentHP).should.equal 84

    it 'is 2x if the pokemon has Adaptability', ->
      shared.create.call this,
        team1: [Factory('Porygon-Z')]
        team2: [Factory('Mew')]
      @battle.makeMove(@player1, 'Tri Attack')
      hp = @team2.at(0).currentHP
      @battle.continueTurn()
      (hp - @team2.at(0).currentHP).should.equal 214

  describe 'turn order', ->
    it 'randomly decides winner if pokemon have the same speed and priority', ->
      shared.create.call this,
        team1: [Factory('Mew')]
        team2: [Factory('Mew')]
      spy = sinon.spy(@battle, 'orderIds')
      shared.biasRNG.call(this, "next", "turn order", .6)
      @battle.makeMove(@player1, 'Psychic')
      @battle.makeMove(@player2, 'Psychic')
      spy.returned([@id2, @id1]).should.be.true

      shared.biasRNG.call(this, "next", "turn order", .4)
      @battle.makeMove(@player1, 'Psychic')
      @battle.makeMove(@player2, 'Psychic')
      spy.returned([@id1, @id2]).should.be.true

    it 'decides winner by highest priority move', ->
      shared.create.call this,
        team1: [Factory('Hitmonchan')]
        team2: [Factory('Hitmonchan')]
      spy = sinon.spy(@battle, 'orderIds')
      @battle.makeMove(@player1, 'Mach Punch')
      @battle.makeMove(@player2, 'ThunderPunch')
      spy.returned([@id1, @id2]).should.be.true

      @battle.makeMove(@player1, 'ThunderPunch')
      @battle.makeMove(@player2, 'Mach Punch')
      spy.returned([@id2, @id1]).should.be.true

    it 'decides winner by speed if priority is equal', ->
      shared.create.call this,
        team1: [Factory('Hitmonchan')]
        team2: [Factory('Hitmonchan', evs: { speed: 4 })]
      spy = sinon.spy(@battle, 'orderIds')
      @battle.makeMove(@player1, 'ThunderPunch')
      @battle.makeMove(@player2, 'ThunderPunch')
      spy.returned([@id2, @id1]).should.be.true

  describe 'fainting all the opposing pokemon', ->
    it "doesn't request any more actions from players", ->
      shared.create.call this,
        team1: [Factory('Hitmonchan')]
        team2: [Factory('Mew')]
      @team2.at(0).currentHP = 1
      @battle.makeMove(@player1, 'Mach Punch')
      @battle.makeMove(@player2, 'Psychic')
      @battle.requests.should.not.have.property @player1.id
      @battle.requests.should.not.have.property @player2.id

    it 'ends the battle', ->
      shared.create.call this,
        team1: [Factory('Hitmonchan')]
        team2: [Factory('Mew')]
      @team2.at(0).currentHP = 1
      mock = sinon.mock(@battle)
      mock.expects('endBattle').once()
      @battle.makeMove(@player1, 'Mach Punch')
      @battle.makeMove(@player2, 'Psychic')
      mock.verify()

  describe 'a pokemon with a type immunity', ->
    it 'cannot be damaged by a move of that type', ->
      shared.create.call this,
        team1: [Factory('Camerupt')]
        team2: [Factory('Gyarados')]
      @battle.makeMove(@player1, 'Earthquake')
      @battle.makeMove(@player2, 'Dragon Dance')

      @team2.at(0).currentHP.should.equal @team2.at(0).stat('hp')

  moveTests.test()
  itemTests.test()

  describe 'a confused pokemon', ->
    it "has a 50% chance of hurting itself", ->
      shared.create.call(this)

      shared.biasRNG.call(this, "randInt", 'confusion turns', 1)  # always 1 turn
      @team1.at(0).attach(new Attachment.Confusion({@battle}))
      shared.biasRNG.call(this, "next", 'confusion', 0)  # always hits

      mock = sinon.mock(moves['tackle'])
      mock.expects('execute').never()

      @battle.makeMove(@player1, 'Tackle')
      @battle.makeMove(@player2, 'Splash')

      mock.restore()
      mock.verify()

      @team1.at(0).currentHP.should.be.lessThan @team1.at(0).stat('hp')
      @team2.at(0).currentHP.should.equal @team2.at(0).stat('hp')

    it "snaps out of confusion after a predetermined number of turns", ->
      shared.create.call(this)

      shared.biasRNG.call(this, "randInt", 'confusion turns', 1)  # always 1 turn
      @team1.at(0).attach(new Attachment.Confusion({@battle}))

      @battle.makeMove(@player1, 'Splash')
      @battle.makeMove(@player2, 'Splash')

      @battle.makeMove(@player1, 'Splash')
      @battle.makeMove(@player2, 'Splash')

      @team1.at(0).hasAttachment(VolatileStatus.CONFUSION).should.be.false

  describe 'a frozen pokemon', ->
    it "will not execute moves", ->
      shared.create.call(this)

      @team1.at(0).attach(new Attachment.Freeze())
      shared.biasRNG.call(this, "next", 'unfreeze chance', 1)  # always stays frozen

      mock = sinon.mock(moves['tackle'])
      mock.expects('execute').never()

      @battle.makeMove(@player1, 'Tackle')
      @battle.makeMove(@player2, 'Splash')

      mock.restore()
      mock.verify()

    it "has a 20% chance of unfreezing", ->
      shared.create.call(this)

      @team1.at(0).attach(new Attachment.Freeze())
      shared.biasRNG.call(this, "next", 'unfreeze chance', 0)  # always unfreezes

      @battle.makeMove(@player1, 'Splash')
      @battle.makeMove(@player2, 'Splash')

      @team1.at(0).hasAttachment(Status.FREEZE).should.be.false

    for moveName in ["Sacred Fire", "Flare Blitz", "Flame Wheel", "Fusion Flare", "Scald"]
      it "automatically unfreezes if using #{moveName}", ->
        shared.create.call(this)

        @team1.at(0).attach(new Attachment.Freeze())
        shared.biasRNG.call(this, "next", 'unfreeze chance', 1)  # always stays frozen

        @battle.makeMove(@player1, moveName)
        @battle.makeMove(@player2, 'Splash')

        @team1.at(0).hasAttachment(Status.FREEZE).should.be.false

  describe "a paralyzed pokemon", ->
    it "has a 25% chance of being fully paralyzed", ->
      shared.create.call(this)

      @team1.first().attach(new Attachment.Paralysis())
      shared.biasRNG.call(this, "next", 'paralyze chance', 0)  # always stays frozen

      mock = sinon.mock(moves['tackle'])
      mock.expects('execute').never()

      @battle.makeMove(@player1, 'Tackle')
      @battle.makeMove(@player2, 'Splash')

      mock.restore()
      mock.verify()

    it "has its speed quartered", ->
      shared.create.call(this)

      speed = @team1.first().stat('speed')
      @team1.first().attach(new Attachment.Paralysis())

      @team1.first().stat('speed').should.equal Math.floor(speed / 4)
