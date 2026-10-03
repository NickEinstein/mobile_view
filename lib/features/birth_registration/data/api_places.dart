import 'package:vital_reg_mobile/core/error/failure.dart';
import 'package:vital_reg_mobile/core/network/api_client.dart';
import 'package:vital_reg_mobile/core/result/result.dart';
import 'package:vital_reg_mobile/core/session/user_scope.dart';
import 'package:vital_reg_mobile/features/birth_registration/data/dtos/birth_registration_dtos.dart';
import 'package:vital_reg_mobile/features/birth_registration/domain/entities/reference_data.dart';

/// Places from `/option/*`: countries, states and centres once; a state's
/// LGAs once it is chosen.
typedef ApiPlacesBase = ({
  List<Option> countries,
  List<Option> nationalities,
  List<StateOption> states,

  /// Every registration centre, with its LGA (`LGA_ID`).
  List<({Option option, String lga})> centres,
});

class ApiPlaces {
  ApiPlaces({required ApiClient client, required UserScope scope})
    : _client = client,
      _base = UserCache(scope),
      _lgas = UserCache(scope);

  final ApiClient _client;
  final UserCache<({ApiPlacesBase places, List<CentreRow> centres})> _base;
  final UserCache<Map<String, List<LgaOption>>> _lgas;

  /// LGA requests in flight, so a state asked for twice is fetched once.
  final _pendingLgas = <String, Future<(String, Result<List<LgaRow>>)>>{};

  /// Countries, nationalities and Nigeria's states, without their LGAs.
  Future<Result<ApiPlacesBase>> base() async => switch (await _loadBase()) {
    Ok(:final value) => Ok(value.places),
    Err(:final failure) => Err(failure),
  };

  Future<Result<({ApiPlacesBase places, List<CentreRow> centres})>>
  _loadBase() async {
    if (_base.value case final cached?) return Ok(cached);
    final (countries, states, centres) = await (
      _client.get('/option/country', decode: countriesFromJson),
      _client.get(
        '/option/states/${ReferenceData.nigeria}',
        decode: stateRowsFromJson,
      ),
      _client.get('/option/registration-centres', decode: centreRowsFromJson),
    ).wait;
    switch ((countries, states, centres)) {
      case (Ok(value: final c), Ok(value: final s), Ok(value: final r)):
        final loaded = (
          places: (
            countries: c.countries,
            nationalities: c.nationalities,
            states: statesFromRows(s),
            centres: [
              for (final centre in r)
                (option: Option(centre.id, centre.name), lga: centre.lga),
            ],
          ),
          centres: r,
        );
        _base.value = loaded;
        return Ok(loaded);
      case (Err(:final failure), _, _) ||
          (_, Err(:final failure), _) ||
          (_, _, Err(:final failure)):
        return Err(failure);
    }
  }

  /// Every state's LGAs loaded so far, after fetching those of [stateIds]
  /// not yet loaded. If any of them fails, the others are still kept.
  Future<Result<Map<String, List<LgaOption>>>> lgas(
    Iterable<String> stateIds,
  ) async {
    final lgas = _lgas.value ??= {};
    final missing = [
      for (final id in {...stateIds})
        if (!lgas.containsKey(id)) id,
    ];
    if (missing.isEmpty) return Ok(lgas);
    final base = await _loadBase();
    if (base case Err(:final failure)) return Err(failure);
    final centres =
        (base as Ok<({ApiPlacesBase places, List<CentreRow> centres})>)
            .value
            .centres;
    final fetched = await Future.wait([
      for (final stateId in missing)
        _pendingLgas[stateId] ??= _fetchLgas(stateId).whenComplete(
          // Not `remove`: it returns this same future, and whenComplete
          // would wait on it forever.
          () => _pendingLgas.removeWhere((id, _) => id == stateId),
        ),
    ]);
    Failure? failed;
    for (final (stateId, result) in fetched) {
      switch (result) {
        case Ok(value: final rows):
          lgas[stateId] = lgasWithCentres(rows, centres);
        case Err(:final failure):
          failed ??= failure;
      }
    }
    return failed != null ? Err(failed) : Ok(lgas);
  }

  Future<(String, Result<List<LgaRow>>)> _fetchLgas(String stateId) async => (
    stateId,
    await _client.get(
      '/option/lga/${Uri.encodeComponent(stateId)}',
      decode: lgaRowsFromJson,
    ),
  );
}
