package com.rojo1112.plataclara.ui

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.unit.dp
import com.rojo1112.plataclara.core.Money
import java.time.Instant
import java.time.LocalDateTime
import java.time.ZoneId
import java.time.format.DateTimeFormatter
import java.util.Locale

val inputFormat: DateTimeFormatter = DateTimeFormatter.ofPattern("yyyy-MM-dd HH:mm")
val listFormat: DateTimeFormatter = DateTimeFormatter.ofPattern("d MMM yyyy, HH:mm", Locale("es", "CO"))
val dayFormat: DateTimeFormatter = DateTimeFormatter.ofPattern("d MMM yyyy", Locale("es", "CO"))

fun formatInput(date: Instant, zone: ZoneId): String = date.atZone(zone).format(inputFormat)

/** Devuelve null si el texto no tiene el formato aaaa-mm-dd hh:mm. */
fun parseInput(text: String, zone: ZoneId): Instant? = try {
    LocalDateTime.parse(text.trim(), inputFormat).atZone(zone).toInstant()
} catch (e: Exception) {
    null
}

@Composable
fun <T> Picker(
    label: String,
    value: T?,
    options: List<Pair<T?, String>>,
    onChange: (T?) -> Unit,
    modifier: Modifier = Modifier,
) {
    var open by remember { mutableStateOf(false) }
    val shown = options.firstOrNull { it.first == value }?.second ?: "Elegir…"
    Box(modifier.fillMaxWidth()) {
        OutlinedButton(onClick = { open = true }, modifier = Modifier.fillMaxWidth()) {
            Text("$label: $shown", maxLines = 1)
        }
        DropdownMenu(expanded = open, onDismissRequest = { open = false }) {
            options.forEach { (v, text) ->
                DropdownMenuItem(text = { Text(text) }, onClick = { onChange(v); open = false })
            }
        }
    }
}

@Composable
fun AmountField(label: String, value: Int, onChange: (Int) -> Unit) {
    var text by remember { mutableStateOf(if (value == 0) "" else value.toString()) }
    OutlinedTextField(
        value = text,
        onValueChange = { typed ->
            val digits = typed.filter(Char::isDigit).take(9)
            text = digits
            onChange(digits.toIntOrNull() ?: 0)
        },
        label = { Text(label) },
        supportingText = { if (value > 0) Text(Money.format(value)) },
        keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Number),
        singleLine = true,
        modifier = Modifier.fillMaxWidth(),
    )
}

@Composable
fun NumberField(label: String, value: Int, onChange: (Int) -> Unit) {
    var text by remember { mutableStateOf(value.toString()) }
    OutlinedTextField(
        value = text,
        onValueChange = { typed ->
            val digits = typed.filter(Char::isDigit).take(2)
            text = digits
            onChange(digits.toIntOrNull() ?: 0)
        },
        label = { Text(label) },
        keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Number),
        singleLine = true,
        modifier = Modifier.fillMaxWidth(),
    )
}

@Composable
fun TextRow(left: String, right: String, rightColor: Color = Color.Unspecified, bold: Boolean = false) {
    Row(Modifier.fillMaxWidth().padding(vertical = 4.dp), horizontalArrangement = Arrangement.SpaceBetween, verticalAlignment = Alignment.CenterVertically) {
        Text(left, modifier = Modifier.weight(1f))
        Text(right, color = rightColor, fontWeight = if (bold) FontWeight.SemiBold else FontWeight.Normal)
    }
}

@Composable
fun SectionTitle(text: String) {
    Text(text, style = MaterialTheme.typography.titleMedium, modifier = Modifier.padding(top = 16.dp, bottom = 4.dp))
}

@Composable
fun Hint(text: String) {
    Text(text, style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
}

@Composable
fun Empty(text: String) {
    Column(Modifier.fillMaxWidth().padding(32.dp), horizontalAlignment = Alignment.CenterHorizontally) {
        Text(text, color = MaterialTheme.colorScheme.onSurfaceVariant)
    }
}
