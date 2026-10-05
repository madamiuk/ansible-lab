package pl.ansible.lab.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;

public class AppDataCreateDto {

    @NotBlank(message = "hostname jest wymagany")
    @Size(max = 253, message = "hostname może mieć maksymalnie 253 znaki")
    @Pattern(
            regexp = "^[A-Za-z0-9](?:[A-Za-z0-9.-]*[A-Za-z0-9])?$",
            message = "hostname zawiera niedozwolone znaki"
    )
    private String hostname;

    public AppDataCreateDto() {
    }

    public String getHostname() {
        return hostname;
    }

    public void setHostname(String hostname) {
        this.hostname = hostname;
    }
}
