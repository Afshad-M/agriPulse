cl def mock_state(merged: bool = False, disrupted: bool = False) -> dict[str, any] {
    farmers: list[dict[str, any]] = [
        {"id":"f01","name":"Kamal Perera","district":"Anuradhapura","language":"si"},
        {"id":"f02","name":"Nirosha Silva","district":"Anuradhapura","language":"si"},
        {"id":"f03","name":"S. Rajendran","district":"Jaffna","language":"ta"},
        {"id":"f04","name":"Tharushi Jayasinghe","district":"Kurunegala","language":"si"},
        {"id":"f05","name":"M. Kandasamy","district":"Kilinochchi","language":"ta"},
        {"id":"f06","name":"Ruwan Fernando","district":"Puttalam","language":"si"},
        {"id":"f07","name":"Ayesha Rahman","district":"Trincomalee","language":"en"},
        {"id":"f08","name":"Sunil Bandara","district":"Polonnaruwa","language":"si"},
        {"id":"f09","name":"P. Sivakumar","district":"Vavuniya","language":"ta"},
        {"id":"f10","name":"Iresha Kumari","district":"Matale","language":"si"},
        {"id":"f11","name":"Nimal de Silva","district":"Gampaha","language":"si"},
        {"id":"f12","name":"R. Mahendran","district":"Mannar","language":"ta"}
    ];
    harvests: list[dict[str, any]] = [
        {"id":"h01","farmerId":"f01","crop":"Tomato","kg":620,"readyHour":7,"shelfLifeHours":26},
        {"id":"h02","farmerId":"f02","crop":"Chilli","kg":410,"readyHour":8,"shelfLifeHours":40},
        {"id":"h03","farmerId":"f03","crop":"Onion","kg":780,"readyHour":6,"shelfLifeHours":72},
        {"id":"h04","farmerId":"f04","crop":"Tomato","kg":540,"readyHour":9,"shelfLifeHours":26},
        {"id":"h05","farmerId":"f05","crop":"Chilli","kg":360,"readyHour":10,"shelfLifeHours":40},
        {"id":"h06","farmerId":"f06","crop":"Onion","kg":690,"readyHour":8,"shelfLifeHours":72},
        {"id":"h07","farmerId":"f07","crop":"Tomato","kg":480,"readyHour":11,"shelfLifeHours":26},
        {"id":"h08","farmerId":"f08","crop":"Chilli","kg":520,"readyHour":7,"shelfLifeHours":40},
        {"id":"h09","farmerId":"f09","crop":"Onion","kg":570,"readyHour":9,"shelfLifeHours":72},
        {"id":"h10","farmerId":"f10","crop":"Tomato","kg":450,"readyHour":12,"shelfLifeHours":26},
        {"id":"h11","farmerId":"f11","crop":"Chilli","kg":390,"readyHour":8,"shelfLifeHours":40},
        {"id":"h12","farmerId":"f12","crop":"Onion","kg":610,"readyHour":10,"shelfLifeHours":72}
    ];
    hubs: list[dict[str, any]] = [
        {"id":"hub01","name":"Anuradhapura packhouse","district":"Anuradhapura"},
        {"id":"hub02","name":"Vavuniya collection hub","district":"Vavuniya"},
        {"id":"hub03","name":"Dambulla agro hub","district":"Matale"},
        {"id":"hub04","name":"Kurunegala produce centre","district":"Kurunegala"}
    ];
    markets: list[dict[str, any]] = [
        {"id":"mkt01","name":"Pettah wholesale","prices":{"Tomato":245,"Chilli":620,"Onion":210},"demandCapKg":4800},
        {"id":"mkt02","name":"Dambulla economic centre","prices":{"Tomato":220,"Chilli":590,"Onion":195},"demandCapKg":3800},
        {"id":"mkt03","name":"Kandy central market","prices":{"Tomato":265,"Chilli":650,"Onion":230},"demandCapKg":2900}
    ];
    trucks: list[dict[str, any]] = [
        {"id":"truck01","name":"LakSavi 01","capacityKg":4200,"costPerKm":92,"status":"available"},
        {"id":"truck02","name":"LakSavi 02","capacityKg":3600,"costPerKm":84,"status":"available"},
        {"id":"truck03","name":"LakSavi 03","capacityKg":5000,"costPerKm":105,"status":"available" if not disrupted else "broken"}
    ];
    routes: list[dict[str, any]];
    if merged {
        routes = [
            {"id":"r-merged-01","truckId":"truck01","farmerIds":["f01","f02","f04"],"hubIds":["hub01"],"marketId":"mkt01","distanceKm":168,"hours":5.4},
            {"id":"r-merged-02","truckId":"truck02","farmerIds":["f03","f05","f09","f12"],"hubIds":["hub02"],"marketId":"mkt03","distanceKm":194,"hours":6.2},
            {"id":"r-merged-03","truckId":"truck03","farmerIds":["f06","f07","f08","f10","f11"],"hubIds":["hub03","hub04"],"marketId":"mkt02","distanceKm":212,"hours":7.1}
        ];
    } else {
        routes = [
            {"id":"r01","truckId":"truck01","farmerIds":["f01"],"hubIds":["hub01"],"marketId":"mkt01","distanceKm":82,"hours":3.1},
            {"id":"r02","truckId":"truck02","farmerIds":["f02"],"hubIds":["hub01"],"marketId":"mkt01","distanceKm":91,"hours":3.6},
            {"id":"r03","truckId":"truck03","farmerIds":["f03"],"hubIds":["hub02"],"marketId":"mkt03","distanceKm":108,"hours":4.1},
            {"id":"r04","truckId":"truck01","farmerIds":["f04"],"hubIds":["hub04"],"marketId":"mkt01","distanceKm":74,"hours":2.8},
            {"id":"r05","truckId":"truck02","farmerIds":["f05"],"hubIds":["hub02"],"marketId":"mkt03","distanceKm":96,"hours":3.5},
            {"id":"r06","truckId":"truck03","farmerIds":["f06"],"hubIds":["hub03"],"marketId":"mkt02","distanceKm":88,"hours":3.2},
            {"id":"r07","truckId":"truck01","farmerIds":["f07"],"hubIds":["hub03"],"marketId":"mkt02","distanceKm":103,"hours":3.9},
            {"id":"r08","truckId":"truck02","farmerIds":["f08"],"hubIds":["hub01"],"marketId":"mkt01","distanceKm":79,"hours":3.0},
            {"id":"r09","truckId":"truck03","farmerIds":["f09"],"hubIds":["hub02"],"marketId":"mkt03","distanceKm":112,"hours":4.3},
            {"id":"r10","truckId":"truck01","farmerIds":["f10"],"hubIds":["hub04"],"marketId":"mkt02","distanceKm":68,"hours":2.5},
            {"id":"r11","truckId":"truck02","farmerIds":["f11"],"hubIds":["hub04"],"marketId":"mkt01","distanceKm":72,"hours":2.7},
            {"id":"r12","truckId":"truck03","farmerIds":["f12"],"hubIds":["hub02"],"marketId":"mkt03","distanceKm":118,"hours":4.5}
        ];
    }
    if disrupted {
        routes = [
            {"id":"r-event-01","truckId":"truck01","farmerIds":["f01","f02","f04"],"hubIds":["hub01"],"marketId":"mkt01","distanceKm":176,"hours":5.8},
            {"id":"r-event-02","truckId":"truck02","farmerIds":["f03","f05","f09","f12"],"hubIds":["hub02"],"marketId":"mkt03","distanceKm":202,"hours":6.7}
        ];
    }
    plans: list[dict[str, any]] = [];
    if merged or disrupted {
        plans = [
            {"routeId":routes[0]["id"],"expectedSpoilagePct":7.4,"expectedIncome":1148200,"truckCost":15456},
            {"routeId":routes[1]["id"],"expectedSpoilagePct":8.1,"expectedIncome":1274600,"truckCost":16968}
        ];
    } else {
        for route in routes {
            plans = plans + [{"routeId":route["id"],"expectedSpoilagePct":13.6,"expectedIncome":241800,"truckCost":7544}];
        }
    }
    return {"farmers":farmers,"harvests":harvests,"hubs":hubs,"markets":markets,"trucks":trucks,"routes":routes,"plans":plans};
}

cl def mock_load_seed() -> dict[str, any] {
    return {"data":{"result":{"state":mock_state(),"seeded":{"farmers":12,"harvests":12,"hubs":4,"markets":3,"trucks":3}}}};
}

cl def mock_baseline_plan() -> dict[str, any] {
    return {"data":{"result":{"state":mock_state(),"score":{"baseline":{"spoilagePct":13.6,"income":2901600,"truckCost":90528},"agent":{"spoilagePct":13.6,"income":2901600,"truckCost":90528}}}}};
}

cl def mock_merge_routes() -> dict[str, any] {
    return {"data":{"result":{"steps":[{"stepNo":1,"mergedRouteIds":["r01","r02","r04"],"newRouteId":"r-merged-01","reason":"Shared North Central collection corridor"},{"stepNo":2,"mergedRouteIds":["r03","r05","r09","r12"],"newRouteId":"r-merged-02","reason":"Consolidated northern market deliveries"}],"state":mock_state(merged=True),"score":{"baseline":{"spoilagePct":13.6,"income":2901600,"truckCost":90528},"agent":{"spoilagePct":7.8,"income":2864200,"truckCost":58420}}}}};
}

cl def mock_breakdown() -> dict[str, any] {
    routes: list[dict[str, any]] = mock_state(merged=True)["routes"] as list[dict[str, any]];
    return {"data":{"result":{"diff":{"removedRouteIds":["r-merged-03"],"addedRouteIds":["r-event-01","r-event-02"],"reassigned":[{"routeId":"r-merged-02","fromTruckId":"truck03","toTruckId":"truck02"}],"notes":["LakSavi 03 reported a breakdown","Northern harvests rerouted through the Vavuniya hub"]},"state":mock_state(merged=True,disrupted=True),"score":{"baseline":{"spoilagePct":17.2,"income":2643800,"truckCost":72600},"agent":{"spoilagePct":9.3,"income":2587400,"truckCost":36880}},"explanation":"LakSavi 03 is unavailable. Northern loads are reassigned to LakSavi 02; a two-route plan protects the shortest shelf-life harvests.","messages":[{"farmerId":"f01","farmerName":"Kamal Perera","language":"si","text":"ඔබගේ අස්වැන්න වෙනත් මාර්ගයකින් යොමු කර ඇත.","isFallback":false},{"farmerId":"f03","farmerName":"S. Rajendran","language":"ta","text":"உங்கள் அறுவடை மாற்று வழியில் அனுப்பப்பட்டுள்ளது.","isFallback":false},{"farmerId":"f07","farmerName":"Ayesha Rahman","language":"en","text":"Your harvest is assigned to an alternate route.","isFallback":false}]}}};
}
