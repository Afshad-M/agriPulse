"""agriPulse - Smoke tests for models.jac (owner: A)."""

test "farmer node constructs" {
    f = Farmer(name="Amina");
    assert f.name == "Amina";
}

test "hub route edge carries its fields" {
    a = Hub(name="North");
    b = Hub(name="South");
    a +>:HubRoute(distance_km=12.5, hours=0.5, open=True):+> b;
    links = [edge a ->:HubRoute:->];
    assert len(links) == 1;
    assert links[0].distance_km == 12.5;
}

test "hub market route carries its fields" {
    hub = Hub(name="North");
    market = Market(name="Central");
    hub +>:HubMarketRoute(distance_km=30.0, hours=1.5, open=False):+> market;
    links = [edge hub ->:HubMarketRoute:->];
    assert len(links) == 1;
    assert links[0].open == False;
}
