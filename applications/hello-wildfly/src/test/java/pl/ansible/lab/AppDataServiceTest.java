package pl.ansible.lab;

import jakarta.persistence.EntityManager;
import org.junit.jupiter.api.Test;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.junit.jupiter.api.extension.ExtendWith;
import pl.ansible.lab.dto.AppDataDto;

import java.time.OffsetDateTime;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.mockito.Mockito.when;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.Mockito.verify;

import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.mockito.Mockito.any;
import static org.mockito.Mockito.never;

@ExtendWith(MockitoExtension.class)
class AppDataServiceTest {

    @Mock
    private EntityManager entityManager;

    @InjectMocks
    private AppDataService appDataService;

    @Test
    void findByIdShouldReturnDtoWhenEntityExists() {
        OffsetDateTime createdAt = OffsetDateTime.parse(
                "2026-10-05T14:00:00+02:00"
        );

        AppData appData = new AppData(
                "test-host",
                createdAt
        );

        when(entityManager.find(AppData.class, 5L))
                .thenReturn(appData);

        AppDataDto result = appDataService.findById(5L);

        assertNotNull(result);
        assertEquals("test-host", result.getHostname());
        assertEquals(createdAt, result.getCreatedAt());
    }

    @Test
    void findByIdShouldReturnNullWhenEntityDoesNotExist() {
        when(entityManager.find(AppData.class, 999L))
                .thenReturn(null);

        AppDataDto result = appDataService.findById(999L);

        assertNull(result);
    }

    @Test
    void updateShouldChangeHostnameWhenEntityExists() {
        OffsetDateTime createdAt = OffsetDateTime.parse(
                "2026-10-05T14:00:00+02:00"
        );

        AppData appData = new AppData(
                "old-host",
                createdAt
        );

        when(entityManager.find(AppData.class, 5L))
                .thenReturn(appData);

        AppDataDto result =
                appDataService.update(5L, "new-host");

        assertNotNull(result);
        assertEquals("new-host", result.getHostname());
        assertEquals(createdAt, result.getCreatedAt());
    }

    @Test
    void updateShouldReturnNullWhenEntityDoesNotExist() {
        when(entityManager.find(AppData.class, 999L))
                .thenReturn(null);

        AppDataDto result =
                appDataService.update(999L, "does-not-exist");

        assertNull(result);
    }

    @Test
    void deleteShouldRemoveEntityWhenItExists() {
        AppData appData = new AppData(
                "delete-test",
                OffsetDateTime.parse("2026-10-05T14:00:00+02:00")
        );

        when(entityManager.find(AppData.class, 5L))
                .thenReturn(appData);

        boolean result = appDataService.delete(5L);

        assertTrue(result);
        verify(entityManager).remove(appData);
    }

    @Test
    void deleteShouldReturnFalseWhenEntityDoesNotExist() {
        when(entityManager.find(AppData.class, 999L))
                .thenReturn(null);

        boolean result = appDataService.delete(999L);

        assertFalse(result);
        verify(entityManager, never()).remove(any());
    }

    @Test
    void createShouldPersistEntityAndReturnDto() {
        AppDataDto result = appDataService.create("create-test");

        assertNotNull(result);
        assertEquals("create-test", result.getHostname());
        assertNotNull(result.getCreatedAt());

        verify(entityManager).persist(any(AppData.class));
    }

}
