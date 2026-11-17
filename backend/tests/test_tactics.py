import pytest
from pydantic import ValidationError

from app.schemas.v1 import TacticIn


FORMATION_433 = ["GK", "LB", "CB", "CB", "RB", "CM", "CM", "CM", "LW", "ST", "RW"]


def test_tactic_allows_repeated_position_labels_for_different_players() -> None:
    tactic = TacticIn(
        title="Starting eleven",
        formation="4-4-2",
        lineup=[
            {"position": position, "player_id": f"player-{index}"}
            for index, position in enumerate(
                ["GK", "LB", "CB", "CB", "RB", "LM", "CM", "CM", "RM", "ST", "ST"]
            )
        ],
    )

    assert len(tactic.lineup) == 11


def test_tactic_rejects_a_player_selected_for_multiple_positions() -> None:
    with pytest.raises(ValidationError, match="can only appear once"):
        TacticIn(
            title="Invalid lineup",
            formation="4-3-3",
            lineup=[
                {
                    "position": position,
                    "player_id": "player-1" if index in (1, 2) else f"player-{index}",
                }
                for index, position in enumerate(FORMATION_433)
            ],
        )


def test_tactic_rejects_an_incomplete_known_formation() -> None:
    with pytest.raises(ValidationError, match="all starting positions must be filled"):
        TacticIn(
            title="Incomplete lineup",
            formation="4-3-3",
            lineup=[
                {"position": position, "player_id": f"player-{index}"}
                for index, position in enumerate(FORMATION_433[:-1])
            ],
        )
