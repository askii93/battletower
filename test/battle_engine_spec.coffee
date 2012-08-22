
{Battle, Pokemon} = require('../').server

describe 'Mechanics', ->
  beforeEach ->
    @player1 = {id: 'abcde'}
    @player2 = {id: 'fghij'}
    team1   = [{}, {}]
    team2   = [{}, {}]
    players = [{player: @player1, team: team1},
               {player: @player2, team: team2}]
    @battle = new Battle(players: players)
    @team1  = @battle.getTeam(@player1.id)
    @team2  = @battle.getTeam(@player2.id)

  describe 'splash', ->
    it 'does no damage', ->
      defender = @team2[0]
      originalHP = defender.currentHP
      @battle.makeMove(@player1, 'splash')
      @battle.endTurn()
      defender.currentHP.should.be.equal originalHP