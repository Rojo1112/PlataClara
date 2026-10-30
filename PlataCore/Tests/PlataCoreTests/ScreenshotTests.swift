import XCTest
@testable import PlataCore

final class ScreenshotTests: XCTestCase {
    let cal = Calendar(identifier: .gregorian)
    // Lunes 5 de octubre de 2026, 13:10
    var now: Date { cal.date(from: DateComponents(year: 2026, month: 10, day: 5, hour: 13, minute: 10))! }

    func testListaConFechaYMonto() {
        let text = """
        1:08
        4G 75
        Buscar movimiento
        Pagaste en NEQUI S.A. -$75.000,00
        COMPAÑÍA DE
        FINANCIAMIENTO
        05 oct - 11:59
        Hicimos un reembolso +$5.410,00
        05 oct - 11:41
        UBER*RIDES -$5.410,00
        05 oct - 11:19
        """
        let entries = ScreenshotParser.parse(text: text, now: now, calendar: cal)
        XCTAssertEqual(entries.count, 3)
        XCTAssertEqual(entries[0].description, "Pagaste en NEQUI S.A. COMPAÑÍA DE FINANCIAMIENTO")
        XCTAssertEqual(entries[0].amount, 75_000)
        XCTAssertEqual(entries[0].kind, .gasto)
        XCTAssertEqual(cal.component(.hour, from: entries[0].date), 11)
        XCTAssertEqual(entries[1].kind, .ingreso)
        XCTAssertEqual(entries[1].amount, 5_410)
        XCTAssertEqual(entries[2].kind, .gasto)
    }

    func testTarjetaConEncabezadoDeDia() {
        let text = """
        Hoy
        Uber*Rides $4.250,00
        11:03
        a 1 meses
        Sábado
        Uber*Rides $13.480,00
        23:37
        a 1 meses
        ¡Gracias por tu pago!
        Pagaste $80.000,00
        Viernes
        Comisión por servicio $6.500,00
        14:03
        """
        let entries = ScreenshotParser.parse(text: text, now: now, calendar: cal)
        XCTAssertEqual(entries.map(\.amount), [4_250, 13_480, 80_000, 6_500])
        XCTAssertEqual(entries[2].kind, .transferencia)
        XCTAssertEqual(entries[3].kind, .gasto)
        XCTAssertEqual(cal.component(.day, from: entries[0].date), 5)
        XCTAssertEqual(cal.component(.day, from: entries[1].date), 3)  // sábado anterior
        XCTAssertEqual(cal.component(.day, from: entries[3].date), 2)  // viernes anterior
    }

    func testCapturasRepetidasNoDuplican() {
        let text = "UBER*RIDES -$5.410,00\n05 oct - 11:19\n\(ScreenshotParser.pageBreak)\nUBER*RIDES -$5.410,00\n05 oct - 11:19"
        XCTAssertEqual(ScreenshotParser.parse(text: text, now: now, calendar: cal).count, 1)
    }

    func testCajitasSonTrasladoNoIngresoNiGasto() {
        let text = """
        Agregaste dinero a tu -$100.000,00
        Cajita Mi primera Cajita
        04 oct - 12:12
        Retiraste dinero de tu +$309.000,00
        Cajita ahorro moto
        03 oct - 19:03
        LA CAJITA FELIZ -$20.000,00
        03 oct - 13:00
        """
        let entries = ScreenshotParser.parse(text: text, now: now, calendar: cal)
        XCTAssertEqual(entries.map(\.kind), [.transferencia, .transferencia, .gasto])
        XCTAssertEqual(entries.map(\.pocket), [.toPocket, .fromPocket, nil])
        XCTAssertEqual(entries.map(\.amount), [100_000, 309_000, 20_000])
    }

    func testFilaPartidaEntreDosCapturasSeCompleta() {
        let first = """
        Pagaste tu tarjeta -$50.000,00
        04 oct - 15:17
        Retiraste dinero de tu +$100.135,00
        """
        let second = """
        12:44
        5G 80
        Q Buscar movimiento
        Cajita Mi primera Cajita
        04 oct - 15:16
        Enviaste a CARLOS DEMO -$20.000,00
        04 oct - 13:22
        """
        let entries = ScreenshotParser.parse(text: [first, second].joined(separator: "\n\(ScreenshotParser.pageBreak)\n"),
                                             now: now, calendar: cal)
        XCTAssertEqual(entries.map(\.amount), [50_000, 100_135, 20_000])
        XCTAssertEqual(entries[1].description, "Retiraste dinero de tu Cajita Mi primera Cajita")
        XCTAssertEqual(entries[1].pocket, .fromPocket)
        XCTAssertEqual(cal.component(.hour, from: entries[1].date), 15)  // no la hora del reloj del teléfono (12:44)
        XCTAssertEqual(cal.component(.minute, from: entries[1].date), 16)
    }

    func testFilaPartidaQueSeRepiteEnteraNoDuplica() {
        let first = "Pagaste tu tarjeta -$6.000,00\n03 oct - 17:25\nEnviaste a ANA DEMO -$7.000,00"
        let second = "Enviaste a ANA DEMO -$7.000,00\n03 oct - 18:53 • Bre-B\nNOVAVENTA -$3.500,00\n03 oct - 13:02"
        let entries = ScreenshotParser.parse(text: [first, second].joined(separator: "\n\(ScreenshotParser.pageBreak)\n"),
                                             now: now, calendar: cal)
        XCTAssertEqual(entries.map(\.amount), [6_000, 7_000, 3_500])
    }

    func testDosMovimientosIgualesEnElMismoMinutoNoSePierden() {
        // Dos reembolsos de $4.300 a las 11:44, cada uno con su compra; el primero sale en una captura y el segundo en la otra.
        let first = """
        PAYU*UBER -$3.915,00
        04 oct - 18:12
        Hicimos un reembolso +$4.300,00
        04 oct - 11:44
        TIENDA DEMO -$4.300,00
        04 oct - 11:44
        """
        let second = """
        04 oct - 11:44
        Hicimos un reembolso +$4.300,00
        04 oct - 11:44
        TIENDA DEMO -$4.300,00
        04 oct - 11:43
        UBER RIDES -$4.912,00
        04 oct - 10:02
        """
        let entries = ScreenshotParser.parse(text: [first, second].joined(separator: "\n\(ScreenshotParser.pageBreak)\n"),
                                             now: now, calendar: cal)
        XCTAssertEqual(entries.count, 6)
        XCTAssertEqual(entries.filter { $0.kind == .ingreso && $0.amount == 4_300 }.count, 2)
        XCTAssertEqual(entries.filter { $0.kind == .gasto && $0.amount == 4_300 }.count, 2)
    }

    func testFilaQueElOcrSeSaltaEnUnaCapturaNoDuplicaLasDemas() {
        let rows = ["NOVAVENTA -$4.000,00\n04 oct - 14:44", "Hicimos un reembolso +$3.500,00\n04 oct - 14:43",
                    "NOVAVENTA -$3.500,00\n04 oct - 14:43", "UBER*RIDES -$7.280,00\n04 oct - 11:41"]
        let first = rows.joined(separator: "\n")
        let second = [rows[0], rows[2], rows[3]].joined(separator: "\n")  // aquí el OCR no leyó el reembolso
        let entries = ScreenshotParser.parse(text: [first, second].joined(separator: "\n\(ScreenshotParser.pageBreak)\n"),
                                             now: now, calendar: cal)
        XCTAssertEqual(entries.count, 4)
    }

    func testCentavosSeRedondeanSinPerderMontosPequenos() {
        let text = "Retiraste dinero de tu Cajita ahorro moto +$0,87\n04 oct - 14:04\nUBER RIDES -$4.916,50\n04 oct - 08:32"
        XCTAssertEqual(ScreenshotParser.parse(text: text, now: now, calendar: cal).map(\.amount), [1, 4_917])
    }

    func testFilaPartidaQueNingunaCapturaCompletaQuedaPorConfirmar() {
        // La captura corta el retiro de las 23:06 y la siguiente empieza en otro movimiento: la fecha no se ve en ninguna.
        let first = """
        Retiraste dinero de tu +$30.000,00
        Cajita ahorro moto
        04 oct - 23:14
        Retiraste dinero de tu +$30.000,00
        Cajita ahorro moto
        NO ant 99.N£
        """
        let second = """
        3:51
        5G 97
        Q Buscar movimiento
        Recibiste de ANA DEMO +$29.500,00
        04 oct - 21:09 • Bre-B
        """
        let entries = ScreenshotParser.parse(text: [first, second].joined(separator: "\n\(ScreenshotParser.pageBreak)\n"),
                                             now: now, calendar: cal)
        XCTAssertEqual(entries.map(\.amount), [30_000, 30_000, 29_500])
        XCTAssertEqual(entries.map(\.dateIsApproximate), [false, true, false])
        XCTAssertEqual(entries[1].description, "Retiraste dinero de tu Cajita ahorro moto")
        XCTAssertEqual(entries[1].pocket, .fromPocket)
        XCTAssertEqual(entries[1].date, entries[0].date)  // se propone la fecha de la fila de arriba
        XCTAssertFalse(entries[1].hasTime)
    }

    func testFilaCortadaAlFinalDeLaUltimaCapturaQuedaPorConfirmar() {
        let entries = ScreenshotParser.parse(text: "UBER RIDES -$4.000,00\n04 oct - 10:00\nNOVAVENTA -$2.000,00",
                                             now: now, calendar: cal)
        XCTAssertEqual(entries.map(\.amount), [4_000, 2_000])
        XCTAssertEqual(entries.map(\.dateIsApproximate), [false, true])
    }

    func testPantallaDeInicioYHoraDeLaCaptura() {
        let home = "12:44\n5G 80\nSaldo disponible\n$63.335,97\nDinero en tus Cajitas\n$ 0,77\nMovimientos\nBuscar movimiento"
        let list = "12:43\nBuscar movimiento\nRetiraste dinero de tu +$30.500,00\nCajita Mi primera Cajita\n21 oct - 12:29"
        XCTAssertTrue(HomeBalanceParser.isHomeScreen(home))
        XCTAssertFalse(HomeBalanceParser.isHomeScreen(list))
        XCTAssertEqual(HomeBalanceParser.parse(text: home), HomeBalance(account: 63_335, pockets: 0))

        let newest = cal.date(from: DateComponents(year: 2026, month: 10, day: 30, hour: 11, minute: 18))!
        let at = HomeBalanceParser.captureDate(text: home, after: newest, calendar: cal)
        XCTAssertEqual(cal.dateComponents([.day, .hour, .minute], from: at), DateComponents(day: 30, hour: 12, minute: 44))
        // Reloj de 12 horas: «3:51» después de un movimiento de las 15:07 es por la tarde.
        let afternoon = cal.date(from: DateComponents(year: 2026, month: 10, day: 30, hour: 15, minute: 7))!
        let pm = HomeBalanceParser.captureDate(text: "3:51\nSaldo disponible\n$50.035,97", after: afternoon, calendar: cal)
        XCTAssertEqual(cal.dateComponents([.hour, .minute], from: pm), DateComponents(hour: 15, minute: 51))
        XCTAssertEqual(HomeBalanceParser.captureDate(text: "Saldo disponible", after: newest, calendar: cal),
                       newest.addingTimeInterval(60))
    }

    func testFechaConCeroEnVezDeO() {
        let entries = ScreenshotParser.parse(text: "UBER RIDES -$3.913,00\n04 0ct- 10:58", now: now, calendar: cal)
        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(cal.component(.month, from: entries[0].date), 10)
    }
}

final class ScreenshotOverlapTests: XCTestCase {
    let cal = Calendar(identifier: .gregorian)

    func testFilasCortadasYBuscadorNoCreanMovimientos() {
        let now = cal.date(from: DateComponents(year: 2026, month: 10, day: 5, hour: 13))!
        let first = """
        1:31
        4G 84
        Q Buscar movimiento
        Recibiste de CARLOS +$250.000,00
        03 oct - 08:49 • Bre-B
        Enviaste a JORGE -$12.000,00
        """
        let second = """
        Q Buscar movimiento
        Enviaste a JORGE ANDRES -$12.000,00
        02 oct - 02:02 • Bre-B
        NOVAVENTA -$3.500,00
        01 oct - 12:08
        Recibiste de ANA +$5.000,00
        """
        let third = """
        Recibiste de ANA DEMO +$5.000,00
        01 oct - 15:11 • Bre-B
        NOVAVENTA -$3.500,00
        01 oct - 12:08
        """
        let text = [first, second, third].joined(separator: "\n\(ScreenshotParser.pageBreak)\n")
        let entries = ScreenshotParser.parse(text: text, now: now, calendar: cal)
        XCTAssertEqual(entries.count, 4)
        XCTAssertEqual(entries[0].description, "Recibiste de CARLOS")
        XCTAssertFalse(entries.contains { $0.description.contains("Buscar") })
        XCTAssertEqual(entries.filter { $0.amount == 3_500 && $0.kind == .gasto }.count, 1)
    }
}
