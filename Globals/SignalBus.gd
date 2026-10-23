extends Node

signal update_fuel(value : float)
signal fuel_depleted
signal update_heat(value : float, max_value : float)
signal score_updated(score : int)
signal run_started(duration : float)
signal time_updated(time_left : float)
signal run_finished(final_score : int, breakdown : Dictionary, quota_met : bool)