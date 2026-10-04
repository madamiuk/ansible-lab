package pl.ansible.lab.dto;

import java.time.OffsetDateTime;

public class AppDataDto {

    private Long id;
    private String hostname;
    private OffsetDateTime createdAt;

    public AppDataDto() {
    }

    public AppDataDto(Long id, String hostname, OffsetDateTime createdAt) {
        this.id = id;
        this.hostname = hostname;
        this.createdAt = createdAt;
    }

    public Long getId() {
        return id;
    }

    public String getHostname() {
        return hostname;
    }

    public OffsetDateTime getCreatedAt() {
        return createdAt;
    }
}
